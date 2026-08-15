# frozen_string_literal: true

# Diagnostics module for Antigravity SDK.
# Probes environment, API key, harness binary, gems, and Gemini API models.
#
# Usage:
#   Antigravity::Diagnostics.run!          # Full colorful output
#   Antigravity::Diagnostics.summary       # Returns hash of all data
#   Antigravity::Diagnostics.check_api_key # Just the key check
#
module Antigravity
  module Diagnostics
    C = Antigravity::Colors

    # Main entry point — prints full colorful diagnostic report
    def self.run!(verbose: false)
      data = summary

      puts ''
      puts C.bold("💎 Antigravity SDK #{C.cyan("v#{data[:sdk_version]}")} — Diagnostics")
      puts C.dim('=' * 56)

      # Ruby
      puts section('💻 Runtime')
      puts field('Ruby', "#{data[:ruby_version]} (#{data[:ruby_platform]})")
      puts field('Bundler', data[:bundler_version])
      puts field('rv', data[:rv_version] || C.dim('not detected'))

      # API Key
      puts section('🔑 Authentication')
      if data[:api_key_present]
        masked = data[:api_key_prefix] + '****' + data[:api_key_suffix]
        source = data[:api_key_source]
        puts field('API Key', "#{C.green(masked)} (#{C.dim(source)})")
      else
        puts field('API Key', C.red('⚠️  NOT SET — export GEMINI_API_KEY'))
      end

      # Model
      puts field('Model', data[:default_model])
      if data[:model_source] == 'default'
        puts C.dim("           └─ using SDK default (set GEMINI_MODEL or ANTIGRAVITY_MODEL to override)")
      end

      # Harness
      puts section('📦 Harness')
      if data[:harness_exists]
        size_mb = (data[:harness_size] / 1_048_576.0).round(1)
        mtime = data[:harness_mtime]&.strftime('%Y-%m-%d %H:%M') || '?'
        puts field('Path', data[:harness_path])
        puts field('Size', "#{size_mb}MB")
        puts field('Modified', mtime)
        puts field('Arch', data[:harness_arch] || C.dim('unknown'))
      else
        puts field('Path', C.red("⚠️  NOT FOUND at #{data[:harness_path]}"))
        puts C.dim("           └─ run: just harness-fetch")
      end

      # Gems
      puts section('📚 Dependencies')
      data[:gems].each do |name, ver|
        status = ver ? C.green(ver) : C.red('missing')
        puts field(name, status)
      end

      # Timeouts
      puts section('⏱️  Timeouts')
      puts field('LLM', "#{data[:timeout_llm]}s")
      puts field('WebSocket', "#{data[:timeout_ws]}s")
      puts field('Handshake', "#{data[:timeout_handshake]}s")

      # Gemini API models probe (optional, needs network)
      if data[:api_key_present] && verbose
        puts section('🤖 Gemini API Models')
        models = probe_models(data[:api_key_raw])
        if models
          puts field('Available', "#{C.green(models[:count].to_s)} models")
          flash = models[:names].select { |n| n.include?('flash') }.first(3)
          pro = models[:names].select { |n| n.include?('pro') }.first(3)
          puts field('Flash', flash.join(', ')) unless flash.empty?
          puts field('Pro', pro.join(', ')) unless pro.empty?
        else
          puts field('Status', C.yellow('⚠️  Could not reach Gemini API'))
        end
      elsif data[:api_key_present]
        puts C.dim("\n   Tip: run with --verbose to probe Gemini API models")
      end

      # Overall status
      puts ''
      issues = health_check(data)
      if issues.empty?
        puts C.green('✅ All checks passed — ready to go!')
      else
        puts C.yellow("⚠️  #{issues.length} issue(s) found:")
        issues.each { |i| puts C.yellow("   • #{i}") }
      end
      puts ''

      data
    end

    # Returns a structured hash of all diagnostic data
    def self.summary
      config = Antigravity.config
      api_key = config.api_key&.strip

      # Detect API key source
      api_key_source = if ENV['GEMINI_API_KEY'] && !ENV['GEMINI_API_KEY'].empty?
                         'GEMINI_API_KEY'
                       else
                         '.env or config'
                       end

      # Detect model source
      model_source = if ENV['GEMINI_MODEL'] && !ENV['GEMINI_MODEL'].empty?
                       'GEMINI_MODEL'
                     elsif ENV['ANTIGRAVITY_MODEL'] && !ENV['ANTIGRAVITY_MODEL'].empty?
                       'ANTIGRAVITY_MODEL'
                     else
                       'default'
                     end

      # Harness binary info
      harness_path = config.harness_path
      harness_stat = File.stat(harness_path) rescue nil
      harness_arch = detect_arch(harness_path) if harness_stat

      # rv detection
      rv_version = detect_rv

      # Gem versions — stdlib gems need special detection
      gem_names = %w[websocket dotenv json logger]
      gems = gem_names.to_h do |g|
        ver = Gem.loaded_specs[g]&.version&.to_s
        # Stdlib gems (json, logger) may not appear in loaded_specs
        ver ||= begin
                  old_verbose = $VERBOSE
                  $VERBOSE = nil
                  require g
                  $VERBOSE = old_verbose
                  defined?(Gem) ? Gem.loaded_specs[g]&.version&.to_s : nil
                rescue LoadError
                  nil
                end
        # Last resort: check if the constant exists (stdlib bundled)
        ver ||= '(stdlib)' if %w[json logger].include?(g)
        [g, ver]
      end

      {
        sdk_version: Antigravity::VERSION,
        ruby_version: RUBY_VERSION,
        ruby_platform: RUBY_PLATFORM,
        bundler_version: Bundler::VERSION,
        rv_version: rv_version,
        api_key_present: api_key && !api_key.empty?,
        api_key_prefix: api_key ? api_key[0..5] : '',
        api_key_suffix: api_key ? api_key[-2..] : '',
        api_key_source: api_key_source,
        api_key_raw: api_key,
        default_model: config.default_model,
        model_source: model_source,
        harness_path: harness_path,
        harness_exists: !harness_stat.nil?,
        harness_size: harness_stat&.size || 0,
        harness_mtime: harness_stat&.mtime,
        harness_arch: harness_arch,
        timeout_llm: config.timeout_llm,
        timeout_ws: config.timeout_ws,
        timeout_handshake: config.timeout_handshake,
        gems: gems,
      }
    end

    # Quick health check — returns array of issue strings
    def self.health_check(data = nil)
      data ||= summary
      issues = []
      issues << 'GEMINI_API_KEY is not set' unless data[:api_key_present]
      issues << "Harness binary not found at #{data[:harness_path]}" unless data[:harness_exists]
      issues << 'websocket gem not loaded' unless data.dig(:gems, 'websocket')
      issues
    end

    private

    def self.section(title)
      "\n#{C.bold(title)}"
    end

    def self.field(label, value)
      "   #{C.cyan(label.to_s.ljust(12))} #{value}"
    end

    def self.detect_arch(path)
      return nil unless File.exist?(path)
      output = `file '#{path}' 2>/dev/null`.strip
      case output
      when /arm64/ then 'arm64 (Apple Silicon)'
      when /x86_64/ then 'x86_64 (Intel)'
      when /ELF.*64/ then 'linux-amd64'
      else output.split(':').last&.strip&.slice(0, 40)
      end
    rescue
      nil
    end

    def self.detect_rv
      `rv --version 2>/dev/null`.strip.then { |v| v.empty? ? nil : v }
    rescue
      nil
    end

    def self.probe_models(api_key)
      require 'net/http'
      require 'json'
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{api_key}")
      resp = Net::HTTP.get_response(uri)
      return nil unless resp.is_a?(Net::HTTPSuccess)
      body = JSON.parse(resp.body)
      models = body['models'] || []
      names = models.map { |m| m['name'].to_s.sub('models/', '') }.sort
      { count: names.length, names: names }
    rescue
      nil
    end
  end
end
