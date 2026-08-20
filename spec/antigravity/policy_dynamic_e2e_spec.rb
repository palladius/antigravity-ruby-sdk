# frozen_string_literal: true

# E2E test for dynamic policy injection.
# Tests that add_deny blocks agent from writing to .env files at runtime.
#
# Flow:
#   1. Create agent with :default policy (allows writes)
#   2. Ask agent to write DESCRIPTION="This is a test and should work" to .env
#   3. Verify it succeeds
#   4. Inject policy.add_deny(:write_to_file, when: path('.env'))
#   5. Ask agent to write DESC=ThisShouldFail to .env
#   6. Verify it's blocked (file unchanged)
#
# Run with: bundle exec rspec spec/antigravity/policy_dynamic_e2e_spec.rb

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'Dynamic Policy Deny E2E', :integration do
  before(:all) do
    skip 'GEMINI_API_KEY not set' unless ENV['GEMINI_API_KEY']
    begin
      Antigravity::Connection::LocalConnection.find_binary!
    rescue Antigravity::HarnessNotFoundError
      skip 'localharness binary not found'
    end
  end

  around(:each) do |example|
    Dir.mktmpdir('policy_deny_test') do |tmpdir|
      @tmpdir = tmpdir
      # Create a .env file with initial content
      @env_file = File.join(tmpdir, '.env')
      File.write(@env_file, "# Test .env\nEXISTING=true\n")
      example.run
    end
  end

  after(:each) { @agent&.close! rescue nil }

  def create_agent(**kwargs)
    agent = Antigravity::Agent.new(**kwargs)
    agent.connect!
    agent
  end

  # ---------------------------------------------------------------------------
  # UAT-DENY: Dynamic policy injection blocks .env writes at runtime
  # ---------------------------------------------------------------------------
  describe 'UAT-DENY: Dynamic .env protection' do
    it 'allows .env write before deny, blocks after add_deny' do
      @agent = create_agent(
        workspace: @tmpdir,
        policy: :default,
        system_instruction: <<~PROMPT
          You are a helpful assistant. When asked to add a line to a file,
          use the write_to_file or edit_file tool to append the line.
          Always confirm what you did.
        PROMPT
      )

      # ─── PHASE 1: Write SHOULD succeed ───────────────────────
      response1 = @agent.ask(
        "Append exactly this line to the .env file: DESCRIPTION=\"This is a test and should work\"\n" \
        "Use the file path: #{@env_file}"
      )

      env_content_after_write = File.read(@env_file)
      puts "\n--- Phase 1: After allowed write ---"
      puts "Response: #{response1.content[0..200]}"
      puts "File content:\n#{env_content_after_write}"

      # Verify the write happened
      expect(env_content_after_write).to include('DESCRIPTION')

      # ─── PHASE 2: Inject deny rule ───────────────────────────
      policy = @agent.policy
      expect(policy).to be_a(Antigravity::Policy)

      # Add a debug hook to see what tools the harness actually calls
      tool_calls_log = []
      @agent.before_tool_call do |tool_name, args|
        tool_calls_log << { tool: tool_name, args_keys: args.keys }
        puts "  🔍 Tool call: #{tool_name} | args keys: #{args.keys} | args: #{args.to_s[0..120]}"
      end

      # Block ANY tool that touches .env — wildcard (nil) catches ALL tool names
      # This is critical because the harness may use internal tool names we don't know
      env_path_glob = policy.path('.env', '*.env')
      policy.add_deny(nil, when: env_path_glob)

      # Also block shell commands that reference .env
      policy.add_deny(:run_command, when: policy.cmd('.env'))

      puts "\n--- Phase 2: Deny injected ---"
      # Test with various tool/arg combinations
      puts "Evaluate write_to_file:       #{policy.evaluate(:write_to_file, { path: @env_file })}"
      puts "Evaluate replace_file_content: #{policy.evaluate(:replace_file_content, { TargetFile: @env_file })}"
      puts "Evaluate UNKNOWN_TOOL:         #{policy.evaluate(:any_random_tool, { target_file: @env_file })}"
      puts "Evaluate run_command cat .env:  #{policy.evaluate(:run_command, { command_line: 'cat .env' })}"

      # Verify policy denies even unknown tool names
      result = policy.evaluate(:some_random_tool_xyz, { path: @env_file })
      expect(result[:status]).to eq(:deny)

      # ─── PHASE 3: Write SHOULD fail ──────────────────────────
      # Save content before the blocked attempt
      env_before_blocked = File.read(@env_file)

      response2 = @agent.ask(
        "Append exactly this line to the .env file: DESC=ThisShouldFail\n" \
        "Use the file path: #{@env_file}"
      )

      env_content_after_block = File.read(@env_file)
      puts "\n--- Phase 3: After denied write ---"
      puts "Response: #{response2.content[0..200]}"
      puts "File content:\n#{env_content_after_block}"

      # The file should NOT contain the blocked content
      expect(env_content_after_block).not_to include('ThisShouldFail')
      # The file should be unchanged from before the blocked attempt
      expect(env_content_after_block).to eq(env_before_blocked)

      puts "\n✅ Dynamic policy deny worked! .env protected at runtime."
    end
  end
end
