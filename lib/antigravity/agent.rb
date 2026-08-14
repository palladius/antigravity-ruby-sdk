# frozen_string_literal: true

module Antigravity
  class Agent < Base

    attr_accessor :model, :system_instruction, :api_key
    attr_reader :tools, :skills, :hooks, :sidecars, :client, :logger_guard,
                :workspace, :connection, :conversation

    def initialize(model: nil, system_instruction: nil, tools: [],
                   skills: [], policies: [], policy: nil, workspace: nil, auto_logger: true, log_file: nil, &block)
      @model = model || Antigravity.config.default_model
      @api_key = Antigravity.config.api_key
      @system_instruction = system_instruction
      @workspace = workspace ? File.expand_path(workspace) : nil
      @tools = tools.dup
      @skills = []
      @policies = []
      @sidecars = []
      @hooks = Hooks.new
      @client = Client.new
      @logger_guard = nil
      @connection = nil
      @conversation = nil
      @connected = false

      # Register pre-provided tools into the tool runner
      @tool_runner = ToolRunner.new
      @tools.each { |t| @tool_runner.register(t) }

      # Load skills provided at construction (local paths or GitHub URLs)
      add_skills(skills) unless Array(skills).empty?

      # Resolve policy: sugar (symbol → preset, Policy object → use directly)
      if policy
        resolved = policy.is_a?(Symbol) ? Policy.preset(policy) : policy
        enforce(resolved)
      end

      # Load policies
      policies.each { |p| enforce(p) }

      # Automagic Logger attachment unless disabled via ENV["ANTIGRAVITY_LOGGER"]=false or auto_logger: false
      if auto_logger && logger_enabled?
        attach_logger(log_file)
      end

      yield(self) if block_given?
    end

    def enforce(policy)
      @policies << policy
      before_tool_call do |tool_name, args|
        policy.evaluate(tool_name, args)
      end
    end

    # --- Class Methods ---

    # Block form: opens connection, yields agent, auto-closes.
    def self.open(**kwargs, &block)
      agent = new(**kwargs)
      agent.connect!
      begin
        block.call(agent)
      ensure
        agent.close!
      end
    end

    # --- Connection Lifecycle ---

    def connect!
      return self if @connected

      # Auto-attach lifecycle logger if enabled via env
      if lifecycle_logger_enabled? && !@lifecycle_attached
        LifecycleLogger.attach!(self, verbose: ENV['ANTIGRAVITY_LIFECYCLE_VERBOSE'] == '1')
        @lifecycle_attached = true
      end

      @connection = Connection::LocalConnection.new
      @connection.connect!

      @conversation = Conversation.new(
        ws_client: @connection.ws_client,
        tool_runner: @tool_runner,
        hooks: @hooks
      )

      harness_config = build_harness_config
      @conversation.initialize_session!(harness_config: harness_config)
      @connected = true

      # Emit session_start hook
      hooks.emit(:session_start, {
        model: @model,
        conversation_id: conversation_id,
        workspace: @workspace,
        skills_count: @skills.length,
        tools_count: @tools.length,
      })

      self
    end

    def connected?
      @connected && @connection&.connected?
    end

    def close!
      # Emit session_end hook before teardown
      if @connected
        hooks.emit(:session_end, {
          turn_count: turn_count,
          conversation_id: conversation_id,
        })
      end

      @connected = false
      @connection&.disconnect!
      @connection = nil
      @conversation = nil
    end

    # --- Chat ---

    def prompt(message, timeout: Antigravity.config.timeout_llm, &block)
      connect! unless @connected
      emit_sidecar_event(:prompt_started, prompt: message)
      hooks.run_pre_prompt(message)

      if @connected && @conversation
        response = @conversation.chat(message, timeout: timeout, &block)
      else
        # Legacy mock-client path (unit tests, pre-connection)
        response = client.send_turn(self, message, &block)
      end

      hooks.run_post_response(response)
      emit_sidecar_event(:turn_completed, response: response.content, model: model)

      response
    end
    alias ask prompt

    # --- Metadata Accessors (mirrors Python SDK) ---

    def conversation_id
      @conversation&.conversation_id
    end

    def turn_count
      @conversation&.turn_count || 0
    end

    def session_summary
      return {} unless @conversation

      @conversation.session_summary(model: @model)
    end

    # --- Tool Registration ---

    def register_tool(tool_or_name = nil, description: "", &block)
      if block_given? && tool_or_name
        tool = Tool::Dynamic.new(tool_or_name, description: description, &block)
      elsif tool_or_name.respond_to?(:to_json_schema)
        tool = tool_or_name
      else
        raise ArgumentError, "Invalid tool definition"
      end
      @tools << tool
      @tool_runner.register(tool) if @tool_runner
      tool
    end

    def attach_sidecar(sidecar)
      @sidecars << sidecar
      sidecar
    end

    def attach_logger(log_target = nil, level: :info, silent_notice: false)
      @logger_guard = Guards::AgentLogger.new(log_target, level: level, silent_notice: silent_notice)
      @logger_guard.attach_to(self)
      @logger_guard
    end

    # Add a single skill by path or GitHub URL.
    # Raises if the path resolves to multiple skills (use add_skills instead).
    # @param path_or_url [String] local path or GitHub URL
    # @param skill_name [String, nil] optional specific skill name within a repo
    # @return [Skill] the loaded skill
    def add_skill(path_or_url, skill_name: nil)
      target = skill_name ? "#{path_or_url.to_s.chomp('/')}/#{skill_name}" : path_or_url.to_s
      paths = SkillResolver.resolve(target)
      if paths.size > 1
        raise ArgumentError,
              "add_skill resolved to #{paths.size} skills. Use add_skills instead, " \
              "or specify skill_name: to pick one."
      end
      raise ArgumentError, "No skill found at #{target}" if paths.empty?

      load_single_skill(paths.first)
    end

    # Add one or more skills by path or GitHub URL.
    # Accepts a single string or an array. Each entry is resolved (may expand to multiple).
    # @param paths_or_urls [String, Array<String>] local paths or GitHub URLs
    # @return [Array<Skill>] all loaded skills
    def add_skills(paths_or_urls)
      Array(paths_or_urls).flat_map do |p|
        SkillResolver.resolve(p).map { |skill_path| load_single_skill(skill_path) }
      end
    end

    # Create and add an inline skill (no file needed).
    # @param name [String] skill name
    # @param description [String] what the skill does
    # @param instructions [String] the skill body (markdown)
    # @return [Skill] the inline skill
    def add_inline_skill(name:, description:, instructions:)
      skill = Skill.inline(name: name, description: description, instructions: instructions)
      @skills << skill unless @skills.any? { |s| s.name == skill.name }
      skill
    end

    # List discovered skills in a container path (without loading them).
    # @param path_or_url [String] local path or GitHub URL
    # @return [Array<String>] skill directory paths
    def self.list_skills(path_or_url)
      SkillResolver.resolve(path_or_url)
    end

    # Legacy alias
    alias_method :load_skill, :add_skill

    def before_prompt(&block)
      hooks.before_prompt(&block)
    end

    def after_response(&block)
      hooks.after_response(&block)
    end

    def before_tool_call(&block)
      hooks.before_tool_call(&block)
    end

    def after_tool_call(&block)
      hooks.after_tool_call(&block)
    end
    alias on_tool_call after_tool_call

    def emit_sidecar_event(event_type, payload = {})
      @sidecars.each { |sidecar| sidecar.emit(event_type, payload) }
    end

    private

    def logger_enabled?
      env_val = ENV["ANTIGRAVITY_LOGGER"]&.downcase
      return false if %w[false 0 none no].include?(env_val)

      true
    end

    def lifecycle_logger_enabled?
      # Explicit opt-in
      return true if ENV['ANTIGRAVITY_LIFECYCLE'] == '1'
      # Rails/Rack test or development
      return true if %w[test development].include?(ENV['RAILS_ENV']&.downcase)
      return true if %w[test development].include?(ENV['RACK_ENV']&.downcase)
      # Explicit opt-out
      false
    end

    def build_harness_config
      api_key = ENV.fetch('GEMINI_API_KEY') {
        raise ConfigError, 'GEMINI_API_KEY environment variable is required'
      }

      config = {
        config: {
          models: [
            {
              name: @model,
              geminiApiEndpoint: {
                apiKey: api_key
              }
            }
          ]
        }
      }

      # Add workspaces if specified
      if @workspace
        expanded = File.expand_path(@workspace)
        $stderr.puts "\u231B Indexing workspace: #{expanded} — this may take a moment..."
        config[:config][:workspaces] = [
          {
            filesystemWorkspace: {
              directory: expanded
            }
          }
        ]
      end

      # Add system instructions if specified (protobuf: SystemInstructions.custom.part[])
      effective_instructions = @system_instruction || ''

      # Auto-append workspace tool hints — models (esp. flash-lite) won't use tools unless told
      if @workspace && !effective_instructions.match?(/list_dir|view_file|tools/i)
        tool_hint = 'You have access to the workspace filesystem. Use the available tools (list_dir, view_file, grep_search) to explore it.'
        effective_instructions = effective_instructions.empty? ? tool_hint : "#{effective_instructions}\n#{tool_hint}"
      end

      unless effective_instructions.empty?
        config[:config][:systemInstructions] = {
          custom: {
            part: [{ text: effective_instructions }]
          }
        }
      end

      # Add custom tools
      if @tool_runner && !@tool_runner.empty?
        config[:config][:tools] = @tool_runner.to_harness_tools
      end

      # Enable harness-side built-in tools by default (list_dir, view_file, grep_search, etc.)
      config[:config][:harnessSideTools] = {
        listDir: { enabled: true },
        viewFile: { enabled: true },
        grepSearch: { enabled: true },
        find: { enabled: true },
        writeToFile: { enabled: true },
        fileEdit: { enabled: true },
        readUrlContent: { enabled: true },
        searchWeb: { enabled: true }
      }

      # Wire skills paths for harness (proto field: skills_paths)
      unless @skills.empty?
        skill_paths = @skills.select(&:path).map(&:path)
        config[:config][:skillsPaths] = skill_paths unless skill_paths.empty?
      end

      # App data dir
      config[:config][:appDataDir] = File.expand_path('~/.gemini/antigravity')

      config
    end

    def load_single_skill(skill_path)
      # Dedup by path
      return @skills.find { |s| s.path == skill_path } if @skills.any? { |s| s.path == skill_path }

      skill = Skill.load(skill_path)
      @skills << skill
      skill
    end

    def lifecycle_logger_enabled?
      ENV['ANTIGRAVITY_LIFECYCLE'] == '1'
    end
  end
end
