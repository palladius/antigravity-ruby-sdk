# frozen_string_literal: true

require "yaml"

module Antigravity
  # Represents an Agent Skill loaded from a SKILL.md file or defined inline.
  # Spec: https://agentskills.io/specification
  #
  # A skill directory must contain a SKILL.md with YAML frontmatter:
  #   ---
  #   name: my-skill
  #   description: What this skill does
  #   ---
  #   # Instructions in markdown...
  class Skill < Base

    attr_reader :name, :description, :instructions, :path, :metadata

    # Load a skill from a directory containing SKILL.md.
    # @param path [String] path to skill directory
    def initialize(path)
      @path = File.expand_path(path)
      @metadata = {}
      parse_skill_file
    end

    # Factory: load from directory path.
    def self.load(path)
      new(path)
    end

    # Factory: create an inline skill (no file needed).
    # @param name [String] skill name (lowercase, hyphenated)
    # @param description [String] what the skill does
    # @param instructions [String] the skill instructions (markdown)
    # @return [Skill] an inline skill instance
    def self.inline(name:, description:, instructions:)
      skill = allocate
      skill.send(:init_inline, name: name, description: description, instructions: instructions)
      skill
    end

    # Check if a directory is a valid skill (contains SKILL.md).
    # @param path [String] directory path to check
    # @return [Boolean]
    def self.skill_dir?(path)
      SkillResolver.skill_dir?(path)
    end

    def to_s
      "#<Skill name=#{@name.inspect} path=#{@path.inspect}>"
    end

    def inspect
      "#<Antigravity::Skill name=#{@name.inspect} description=#{@description.inspect} path=#{@path.inspect}>"
    end

    private

    def init_inline(name:, description:, instructions:)
      @name = name
      @description = description
      @instructions = instructions
      @path = nil  # inline skills have no path
      @metadata = {}
    end

    def parse_skill_file
      skill_file = File.join(@path, "SKILL.md")
      raise ArgumentError, "SKILL.md not found at #{@path}" unless File.exist?(skill_file)

      content = File.read(skill_file, encoding: 'UTF-8')
      if content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
        front_matter = YAML.safe_load(Regexp.last_match(1)) || {}
        @name = front_matter["name"] || File.basename(@path)
        @description = front_matter["description"] || ""
        @metadata = front_matter.fetch("metadata", {})
        @instructions = Regexp.last_match.post_match.strip
      else
        @name = File.basename(@path)
        @description = ""
        @instructions = content.strip
      end
    end
  end
end
