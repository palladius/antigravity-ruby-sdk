# frozen_string_literal: true

require 'json'
require_relative 'policy/constants'
require_relative 'policy/riccardo'

module Antigravity
  # ==========================================================================
  # Antigravity::Policy — Declarative tool-access control for agents.
  #
  # ⚠️  ORDER DOES NOT MATTER!
  #
  # The DSL is declarative, like SQL — not imperative like a script.
  # Rules are evaluated by PRECEDENCE, not by insertion order.
  # You can write `allow` before `deny` or vice versa — same result.
  #
  # Precedence (highest wins):
  #   1. Tool specificity:    specific tool > wildcard (nil)
  #   2. Condition specificity: has `when:` > no `when:`
  #   3. Restrictiveness:      deny > confirm > allow
  #
  # Example — these two policies behave identically:
  #
  #   Policy.define do          Policy.define do
  #     allow :run_command        deny :run_command, when: cmd('rm')
  #     deny :run_command,        allow :run_command
  #       when: cmd('rm')       end
  #   end
  #
  # In both cases, `rm` is denied (conditional deny beats unconditional
  # allow), and everything else is allowed.
  #
  # See policy/constants.rb for curated command/file/tool lists.
  # ==========================================================================
  class Policy

    # ------------------------------------------------------------------
    # Rule — a single allow/deny/confirm entry in a policy.
    # ------------------------------------------------------------------
    class Rule
      attr_reader :action, :tool_name, :condition, :handler

      def initialize(action, tool_name = nil, condition: nil, handler: nil)
        @action = action
        @tool_name = tool_name
        @condition = condition
        @handler = handler
      end

      def matches?(tool, args)
        return false if @tool_name && @tool_name.to_sym != tool.to_sym
        return false if @condition && !@condition.call(name: tool, args: args)
        true
      end

      # Precedence order (higher = wins):
      # 1. Tool specificity: Specific tool > Wildcard (nil)
      # 2. Condition specificity: Has predicate > No predicate
      # 3. Action restrictiveness: Deny > Confirm > Allow
      def precedence
        specificity = @tool_name ? 1 : 0
        condition_score = @condition ? 1 : 0
        action_score = case @action
                       when :deny then 3
                       when :confirm then 2
                       when :allow then 1
                       else 0
                       end
        [specificity, condition_score, action_score]
      end
    end

    # ------------------------------------------------------------------
    # Constructor & factory methods
    # ------------------------------------------------------------------

    def initialize(&block)
      @rules = []
      @confirm_handler = nil
      instance_eval(&block) if block_given?
    end

    def self.define(&block)
      new(&block)
    end

    def self.allow_all
      new { allow_all }
    end

    def self.deny_all
      new { deny_all }
    end

    # ------------------------------------------------------------------
    # Built-in presets
    # ------------------------------------------------------------------

    # Resolve a preset by name (symbol).
    # @param name [Symbol] :cautious, :default, :turbo, :test, or :auto
    # @return [Policy]
    def self.preset(name)
      case name.to_sym
      when :cautious then cautious
      when :default  then default
      when :riccardo then riccardo
      when :turbo    then turbo
      when :test     then test
      when :auto     then auto
      else
        raise ArgumentError, "Unknown preset :#{name}. Choose from: #{PRESET_NAMES.map { |n| ":#{n}" }.join(', ')}"
      end
    end

    # Parses a Gemini CLI config.json file to import auto-approved permissions.
    # @param file_path [String] Path to config.json (defaults to ~/.gemini/config/config.json)
    # @param limit [Integer, nil] Optional max number of permissions to import (useful for testing)
    # @return [Policy]
    def self.from_gemini_config(file_path = nil, limit: nil)
      policy = new
      policy.merge_gemini_config(file_path, limit: limit)
      policy
    end

    # Merges permissions from a Gemini CLI config.json into this Policy instance.
    # @param file_path [String] Path to config.json
    # @param limit [Integer, nil] Optional limit on permissions to merge
    # @return [self]
    def merge_gemini_config(file_path = nil, limit: nil)
      file_path = File.expand_path(file_path || '~/.gemini/config/config.json')
      return self unless File.exist?(file_path)

      data = JSON.parse(File.read(file_path, encoding: 'utf-8'))
      gpg = data.dig('userSettings', 'globalPermissionGrants')
      perms = data['autoApprovedPermissions'] || data['auto_approved_permissions']
      if gpg.is_a?(Hash)
        perms ||= gpg['allow'] || gpg['approved']
      elsif gpg.is_a?(Array)
        perms ||= gpg
      end
      perms ||= []
      perms = perms.take(limit) if limit && limit > 0

      cmds = []
      read_paths = []
      write_paths = []
      mcp_tools = []

      perms.each do |perm|
        case perm
        when /^unsandboxed\((.+)\)$/, /^command\((.+)\)$/
          cmds << $1
        when /^read_file\((.+)\)$/
          read_paths << $1
        when /^write_file\((.+)\)$/
          write_paths << $1
        when /^mcp\((.+)\)$/
          mcp_tools << $1
        end
      end

      allow :run_command, when: cmd(*cmds) unless cmds.empty?
      allow :read_file, when: path(*read_paths) unless read_paths.empty?
      allow :write_file, when: path(*write_paths) unless write_paths.empty?
      mcp_tools.uniq.each { |t| allow t.to_sym }

      self
    end

    # Serializes the policy into a clean, DRY human-readable Ruby DSL code string.
    # Groups paths & commands using elegant paths(...) and cmds(...) DSL syntax.
    def to_ruby_dsl
      home = Dir.home
      shrink = ->(p) { p.to_s.start_with?(home) ? p.to_s.sub(home, '~') : p.to_s }

      buf = ['Antigravity.policy do']
      @rules.each do |rule|
        action_str = rule.action.to_s
        tool_str = rule.tool_name ? ":#{rule.tool_name}" : nil
        cond = rule.condition

        if tool_str.nil? && action_str == 'allow'
          buf << '  allow_all'
        elsif tool_str.nil? && action_str == 'deny'
          buf << '  deny_all'
        elsif cond.respond_to?(:type) && cond.type == :cmd
          pats = cond.patterns
          if pats.length > 1
            buf << "  #{action_str} #{tool_str}, when: cmds("
            pats.each { |p| buf << "    '#{p}'," }
            buf << '  )'
          elsif pats.length == 1
            buf << "  #{action_str} #{tool_str}, when: cmd('#{pats.first}')"
          end
        elsif cond.respond_to?(:type) && cond.type == :path
          gls = cond.globs
          if gls.length > 1
            buf << "  #{action_str} #{tool_str}, when: paths("
            gls.each { |g| buf << "    '#{shrink.call(g)}'," }
            buf << '  )'
          elsif gls.length == 1
            buf << "  #{action_str} #{tool_str}, when: path('#{shrink.call(gls.first)}')"
          end
        elsif tool_str
          buf << "  #{action_str} #{tool_str}"
        end
      end
      buf << 'end'
      buf.join("\n")
    end

    # Saves the Ruby DSL policy to a file (defaults to out/sample_policy.rb).
    # Creates parent directories automatically.
    # @param output_file [String] Target file path
    # @return [String] Absolute path to saved file
    def save_ruby_dsl(output_file = 'out/sample_policy.rb')
      require 'fileutils'
      expanded = File.expand_path(output_file)
      FileUtils.mkdir_p(File.dirname(expanded))
      File.write(expanded, to_ruby_dsl + "\n", encoding: 'utf-8')
      expanded
    end

    # 🔒 Cautious — read-only free, confirm everything else, hard-deny destructive.
    # Best for: untrusted environments, production agents.
    # NOTE: cat/head/tail/ls NOT in safe list — they can bypass view_file deny rules.
    def self.cautious
      define do
        deny_all
        READONLY_TOOLS.each { |t| allow t }
        allow :run_command, when: cmd(*SAFE_CMDS, *SAFE_GIT_CMDS)
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        deny :run_command, when: cmd(*RISKY_CMDS)
        deny :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
        WRITE_TOOLS.each { |t| confirm t }
        # 📂 Sandbox dirs: always writable, even in production
        WRITE_TOOLS.each { |t| allow t, when: path(*SANDBOX_DIRS) }
        confirm :run_command
      end
    end

    # ⚖️ Default — balanced: allow reads + writes, confirm dangerous shell, protect sensitive files.
    # Best for: day-to-day development, pair programming with an agent.
    def self.default
      define do
        deny_all
        READONLY_TOOLS.each { |t| allow t }
        WRITE_TOOLS.each { |t| allow t }
        WRITE_TOOLS.each { |t| confirm t, when: path(*SENSITIVE_FILES) }
        allow :run_command
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        confirm :run_command, when: cmd(*RISKY_CMDS)
        confirm :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
      end
    end

    # 🚀 Turbo — wide open with seatbelts: allow everything, only hard-deny catastrophic.
    # Best for: trusted dev environments, rapid prototyping.
    def self.turbo
      define do
        allow_all
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        confirm :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
        WRITE_TOOLS.each { |t| confirm t, when: path(*SENSITIVE_FILES) }
      end
    end

    # 🧪 Test — permissive for test runners, but sandboxed.
    # Best for: CI, test suites, RAILS_ENV=test.
    def self.test
      define do
        allow_all
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        deny :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
        confirm :run_command, when: cmd(*RISKY_CMDS)
        WRITE_TOOLS.each { |t| confirm t, when: path(*SENSITIVE_FILES) }
      end
    end

    # 🔮 Auto — reads RAILS_ENV, RACK_ENV, or ANTIGRAVITY_ENV and picks a preset.
    # Falls back to :default if unrecognized or unset.
    def self.auto
      env = ENV['ANTIGRAVITY_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV']
      preset_name = ENV_MAP.fetch(env.to_s.downcase, :default)
      send(preset_name)
    end

    # ------------------------------------------------------------------
    # DSL methods
    # ------------------------------------------------------------------

    def allow(tool_name = nil, **kwargs)
      @rules << Rule.new(:allow, tool_name, condition: kwargs[:when])
    end

    def deny(tool_name = nil, **kwargs)
      @rules << Rule.new(:deny, tool_name, condition: kwargs[:when])
    end

    def confirm(tool_name = nil, **kwargs, &block)
      @rules << Rule.new(:confirm, tool_name, condition: kwargs[:when], handler: block)
    end

    def allow_all
      allow(nil)
    end

    def deny_all
      deny(nil)
    end

    def confirm_all
      confirm(nil)
    end

    def on_confirm(&block)
      @confirm_handler = block
    end

    # ------------------------------------------------------------------
    # Predicate helpers
    # ------------------------------------------------------------------

    def cmd(*patterns)
      patterns = patterns.flatten
      pred = ->(ctx) do
        args = ctx[:args]
        cmd_arg = args[:command_line] || args['command_line'] || args[:CommandLine] || args['CommandLine']
        return false unless cmd_arg

        cmd_arg = cmd_arg.to_s
        patterns.any? { |p| cmd_arg.include?(p.to_s) }
      end
      pred.define_singleton_method(:type) { :cmd }
      pred.define_singleton_method(:patterns) { patterns }
      pred
    end
    alias cmds cmd

    def path(*globs)
      globs = globs.flatten
      pred = ->(ctx) do
        args = ctx[:args]
        path_arg = args[:path] || args['path'] ||
                   args[:file] || args['file'] ||
                   args[:target] || args['target'] ||
                   args[:file_path] || args['file_path'] ||
                   args[:target_file] || args['target_file']
        return false unless path_arg

        raw_path = path_arg.to_s
        expanded_path = File.expand_path(raw_path) rescue raw_path

        globs.any? do |g|
          expanded_g = File.expand_path(g.to_s) rescue g.to_s
          File.fnmatch?(g.to_s, raw_path) || File.fnmatch?(g.to_s, expanded_path) || File.fnmatch?(expanded_g, expanded_path)
        end
      end
      pred.define_singleton_method(:type) { :path }
      pred.define_singleton_method(:globs) { globs }
      pred
    end
    alias paths path

    def args_match(**matchers)
      ->(ctx) do
        args = ctx[:args]
        matchers.any? do |k, v|
          val = args[k.to_sym] || args[k.to_s]
          val && v.match?(val.to_s)
        end
      end
    end

    # ------------------------------------------------------------------
    # Evaluation engine
    # ------------------------------------------------------------------

    def evaluate(tool_name, args = {})
      matching_rules = @rules.select { |r| r.matches?(tool_name, args) }
      best_rule = matching_rules.max_by(&:precedence)

      if best_rule
        if best_rule.action == :confirm
          handler = best_rule.handler || @confirm_handler
          if handler
            ctx = { name: tool_name, args: args }
            result = handler.call(ctx)
            { status: result ? :allow : :deny }
          else
            { status: :deny }
          end
        elsif best_rule.action == :deny
          { status: :deny, reason: "Denied by policy" }
        else
          { status: :allow }
        end
      else
        { status: :deny } # Default to deny if no rules match
      end
    end
  end
end
