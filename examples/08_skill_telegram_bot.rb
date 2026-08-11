#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 08: Telegram Bot with Skills & Audio Support
# =====================================================
# Runs an Antigravity Agent as a Telegram chatbot.
# Supports text messages, voice/audio transcription, and skills.
#
# Usage:
#   rv run ruby examples/08_skill_telegram_bot.rb
#   just rv-skill-telegram
#
# Required ENV vars (in .env or exported):
#   TELEGRAM_BOT_TOKEN — from @BotFather
#   GEMINI_API_KEY     — for the agent + audio transcription
#
# Inspired by: ~/git/emorr-agy (Go Telegram + Gemini audio patterns)

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'websocket', '~> 1.2'
  gem 'telegram-bot-ruby', '~> 2.0'
  gem 'dotenv', '~> 3.0'
  gem 'base64'  # No longer in Ruby 3.4 default gems
end

# Load .env if present
require 'dotenv/load' if File.exist?(File.expand_path('../../.env', __FILE__))

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'antigravity'
require 'net/http'
require 'json'
require 'base64'
require 'tempfile'
require 'telegram/bot'

# --- Terminal Color Helpers ---
module TermColor
  CODES = { cyan: 36, green: 32, red: 31, yellow: 33, gray: 90, bold: 1, magenta: 35 }.freeze

  CODES.each do |name, code|
    define_method("to_#{name}") { "\e[#{code}m#{self}\e[0m" }
  end
end
String.include(TermColor)

# --- Configuration ---
BOT_TOKEN   = ENV.fetch('TELEGRAM_BOT_TOKEN') { abort '❌ Missing TELEGRAM_BOT_TOKEN in .env' }
GEMINI_KEY  = ENV.fetch('GEMINI_API_KEY')      { abort '❌ Missing GEMINI_API_KEY in .env' }
SKILLS      = ENV.fetch('TELEGRAM_SKILLS', '').split(',').map(&:strip).reject(&:empty?)
AGENT_MODEL = ENV.fetch('GEMINI_MODEL', 'gemini-2.5-flash-lite')
TRANSCRIPTION_MODEL = ENV.fetch('GEMINI_TRANSCRIPTION_MODEL', AGENT_MODEL)

puts '🤖 Antigravity Telegram Bot'.to_bold
puts '=' * 40
puts
puts "📡 Bot token: #{BOT_TOKEN[0..5]}...#{BOT_TOKEN[-4..]}".to_gray
puts "🔑 Gemini key: #{GEMINI_KEY[0..5]}...#{GEMINI_KEY[-4..]}".to_gray
puts "✴️  Agent model: #{AGENT_MODEL}".to_cyan
puts "🎤 Transcription model: #{TRANSCRIPTION_MODEL}".to_cyan
puts "📚 Skills: #{SKILLS.empty? ? '(none)' : SKILLS.join(', ')}".to_yellow
puts

# --- Error Logger (appends to JSONL + red CLI) ---
def log_error(event, detail, chat_id: nil)
  puts "[#{chat_id || '-'}] #{event}: #{detail}".to_red
  entry = { ts: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'), event: event, error: detail }
  entry[:chat_id] = chat_id if chat_id
  File.open('log/telegram.jsonl', 'a') { |f| f.puts(JSON.generate(entry)) } rescue nil
end

# --- Audio Transcription via Gemini Multimodal API ---
# NOTE: GEMINI_MODEL is for the agent (via harness). Transcription uses REST API
# directly, so it needs a model available on v1beta (gemini-2.5-flash-lite works).
module GeminiAudio
  TRANSCRIBE_URL = "https://generativelanguage.googleapis.com/v1beta/models/#{TRANSCRIPTION_MODEL}:generateContent"

  LANG_FLAGS = {
    'it' => "\u{1F1EE}\u{1F1F9}", 'en' => "\u{1F1EC}\u{1F1E7}",
    'es' => "\u{1F1EA}\u{1F1F8}", 'fr' => "\u{1F1EB}\u{1F1F7}",
    'de' => "\u{1F1E9}\u{1F1EA}", 'pt' => "\u{1F1F5}\u{1F1F9}",
    'ja' => "\u{1F1EF}\u{1F1F5}", 'zh' => "\u{1F1E8}\u{1F1F3}",
  }.freeze

  def self.transcribe(audio_path, mime_type, api_key)
    file_data = File.binread(audio_path)
    b64 = Base64.strict_encode64(file_data)

    payload = {
      contents: [{
        parts: [
          { inlineData: { mimeType: mime_type, data: b64 } },
          { text: 'Transcribe the audio verbatim. Identify the primary language (ISO 639-1 code). Return JSON: {"text": "...", "language": "en"}' }
        ]
      }],
      generationConfig: { responseMimeType: 'application/json' }
    }

    uri = URI("#{TRANSCRIBE_URL}?key=#{api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(payload)

    resp = http.request(req)
    resp_body = resp.body
    $stderr.puts "[DEBUG] Gemini transcription HTTP #{resp.code}" 

    unless resp.is_a?(Net::HTTPSuccess)
      return { text: nil, language: nil, flag: nil, error: "Gemini API returned #{resp.code}: #{resp_body[0, 200]}" }
    end

    body = JSON.parse(resp_body)
    raw = body.dig('candidates', 0, 'content', 'parts', 0, 'text')

    unless raw
      # Could be a safety block or empty response
      block_reason = body.dig('candidates', 0, 'finishReason') || body.dig('promptFeedback', 'blockReason')
      return { text: nil, language: nil, flag: nil, error: "Empty transcription (reason: #{block_reason || 'unknown'})" }
    end

    result = JSON.parse(raw)
    flag = LANG_FLAGS[result['language']] || "\u{1F310}"
    { text: result['text'], language: result['language'], flag: flag }
  rescue StandardError => e
    $stderr.puts "[DEBUG] Transcription error: #{e.class}: #{e.message}"
    { text: nil, language: nil, flag: nil, error: e.message }
  end

  def self.download_telegram_file(bot_token, file_id)
    # 1. Get file path from Telegram
    uri = URI("https://api.telegram.org/bot#{bot_token}/getFile?file_id=#{file_id}")
    resp = Net::HTTP.get_response(uri)
    file_path = JSON.parse(resp.body).dig('result', 'file_path')

    # 2. Download the file
    ext = File.extname(file_path).empty? ? '.ogg' : File.extname(file_path)
    tmp = Tempfile.new(['voice', ext])
    tmp.binmode

    dl_uri = URI("https://api.telegram.org/file/bot#{bot_token}/#{file_path}")
    Net::HTTP.start(dl_uri.host, dl_uri.port, use_ssl: true) do |http|
      http.request(Net::HTTP::Get.new(dl_uri)) do |response|
        response.read_body { |chunk| tmp.write(chunk) }
      end
    end
    tmp.close

    mime = ext == '.ogg' ? 'audio/ogg' : "audio/#{ext.delete('.')}"
    { path: tmp.path, mime: mime, tempfile: tmp }
  end
end

# --- Per-Chat Agent Sessions ---
class ChatSession
  attr_reader :chat_id, :agent, :history

  def initialize(chat_id, skills: [])
    @chat_id = chat_id
    @history = []
    @agent = Antigravity::Agent.new(
      skills: skills,
      log_file: 'log/telegram.jsonl',
      system_instruction: "You are a helpful assistant on Telegram. Be concise and use emojis. " \
                          "Keep responses under 4000 characters (Telegram limit). " \
                          "When replying to transcribed voice messages, acknowledge the language."
    )
    @agent.connect!
  end

  def ask(text, &block)
    @history << { role: :user, text: text, at: Time.now }
    response = @agent.ask(text, timeout: 90, &block)
    @history << { role: :assistant, text: response.content, at: Time.now }
    response
  end

  def close!
    @agent.close! rescue nil
  end
end

# --- Main Bot Loop ---
sessions = {}
CHAT_ID = ENV['TELEGRAM_CHAT_ID']&.to_i
VERSION = File.read(File.expand_path('../VERSION', __dir__)).strip rescue '?'

puts "🚀 Starting Telegram long-polling loop...".to_bold
puts "   Press Ctrl+C to stop.".to_gray
puts

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  # Proactive greeting on startup!
  if CHAT_ID && CHAT_ID > 0
    greeting = "💎 *Ruby Antigravity SDK — Telegram Bot* v#{VERSION}\n\n" \
               "✴️ Agent model: `#{AGENT_MODEL}`\n" \
               "🎤 Transcription: `#{TRANSCRIPTION_MODEL}`\n\n" \
               "🤗 Ciao, come butta? Sono il tuo agente Ruby, pronto a servirti!\n\n" \
               "Mandami un messaggio di testo o vocale 🎤\n" \
               "Comandi: /start /skills /stop"
    bot.api.send_message(chat_id: CHAT_ID, text: greeting, parse_mode: 'Markdown')
    puts "👋 Greeting sent to chat #{CHAT_ID}".to_green
  end

  bot.listen do |message|
    chat_id = message.chat.id

    case message
    when Telegram::Bot::Types::CallbackQuery
      bot.api.answer_callback_query(callback_query_id: message.id)
      next

    when Telegram::Bot::Types::Message
      # --- Commands ---
      if message.text&.start_with?('/')
        case message.text.split.first
        when '/reset'
          sessions[chat_id]&.close!
          sessions[chat_id] = ChatSession.new(chat_id, skills: SKILLS)
          bot.api.send_message(
            chat_id: chat_id,
            text: "🔄 *Session reset!* Fresh agent, clean slate.\n\n" \
                  "Skills: #{SKILLS.empty? ? 'none' : SKILLS.map { |s| "`#{File.basename(s)}`" }.join(', ')}",
            parse_mode: 'Markdown'
          )
          puts "[#{chat_id}] /reset - new session".to_yellow
          next

        when '/help'
          bot.api.send_message(
            chat_id: chat_id,
            text: "💎 *Ruby Antigravity SDK* v#{VERSION}\n\n" \
                  "Commands:\n" \
                  "/help \u2014 This message\n" \
                  "/skills \u2014 List loaded skills\n" \
                  "/status \u2014 Session info\n" \
                  "/reset \u2014 New agent session\n" \
                  "/stop \u2014 Shutdown bot\n\n" \
                  "Send text or voice \ud83c\udfa4 messages to chat!",
            parse_mode: 'Markdown'
          )
          next

        when '/skills'
          session = sessions[chat_id]
          if session && !session.agent.skills.empty?
            skill_list = session.agent.skills.map { |s| "- `#{s.name}`: #{s.description.to_s[0, 60]}" }.join("\n")
            bot.api.send_message(chat_id: chat_id, text: "\ud83d\udcda *Loaded Skills:*\n#{skill_list}", parse_mode: 'Markdown')
          else
            bot.api.send_message(chat_id: chat_id, text: "\ud83d\udcda No skills loaded. Set TELEGRAM\\_SKILLS in .env")
          end
          next

        when '/status'
          session = sessions[chat_id]
          turns = session ? session.history.size : 0
          bot.api.send_message(
            chat_id: chat_id,
            text: "\u2734\ufe0f Agent: `#{AGENT_MODEL}`\n" \
                  "\ud83c\udfa4 Transcription: `#{TRANSCRIPTION_MODEL}`\n" \
                  "\ud83d\udcac Turns: #{turns}\n" \
                  "\ud83d\udcda Skills: #{SKILLS.size}",
            parse_mode: 'Markdown'
          )
          next

        when '/stop'
          bot.api.send_message(chat_id: chat_id, text: "\ud83d\udc4b Shutting down bot... Arrivederci!")
          puts "\ud83d\udc4b /stop received from #{chat_id} - shutting down".to_red
          sessions.each_value(&:close!)
          exit(0)
        end
      end

      # --- Ensure session exists ---
      sessions[chat_id] ||= ChatSession.new(chat_id, skills: SKILLS)
      session = sessions[chat_id]

      # --- Voice / Audio Messages ---
      if message.voice || message.audio
        file_id = (message.voice || message.audio).file_id
        mime = (message.voice || message.audio).mime_type || 'audio/ogg'

        bot.api.send_message(chat_id: chat_id, text: "🎤 Transcribing voice message...")

        begin
          dl = GeminiAudio.download_telegram_file(BOT_TOKEN, file_id)
          result = GeminiAudio.transcribe(dl[:path], dl[:mime], GEMINI_KEY)
          dl[:tempfile].unlink # Clean up temp file

          if result[:error]
            bot.api.send_message(chat_id: chat_id, text: "❌ Transcription failed: #{result[:error]}")
            log_error('transcription_error', result[:error], chat_id: chat_id)
            next
          end

          bot.api.send_message(
            chat_id: chat_id,
            text: "#{result[:flag]} _#{result[:text]}_",
            parse_mode: 'Markdown'
          )

          # Feed transcribed text to agent
          user_text = result[:text]
        rescue StandardError => e
          bot.api.send_message(chat_id: chat_id, text: "❌ Audio error: #{e.message}")
          log_error('audio_error', e.message, chat_id: chat_id)
          next
        end
      else
        user_text = message.text
      end

      next unless user_text && !user_text.empty?

      puts "[#{chat_id}] 👤 #{user_text}".to_cyan

      # --- Send to Agent ---
      bot.api.send_chat_action(chat_id: chat_id, action: 'typing')

      begin
        full_response = ""
        response = session.ask(user_text) do |chunk|
          full_response += chunk.content if chunk.content
        end

        # Telegram max message is 4096 chars
        if full_response.length > 4000
          full_response = full_response[0, 3990] + "\n\n_(truncated)_"
        end

        preview = full_response.empty? ? '(empty)' : full_response[0, 200]
        puts "[#{chat_id}] 🤖 #{preview}#{'...' if full_response.length > 200}".to_green

        bot.api.send_message(
          chat_id: chat_id,
          text: full_response.empty? ? "🤔 No response generated." : full_response,
          parse_mode: 'Markdown'
        ) rescue bot.api.send_message(chat_id: chat_id, text: full_response) # Fallback without Markdown if parsing fails
      rescue StandardError => e
        bot.api.send_message(chat_id: chat_id, text: "❌ Agent error: #{e.message}")
        log_error('agent_error', e.message, chat_id: chat_id)
      end
    end
  end
rescue Interrupt
  puts "\n👋 Bot stopped. Cleaning up sessions..."
  sessions.each_value(&:close!)
  puts "✅ Done!"
end
