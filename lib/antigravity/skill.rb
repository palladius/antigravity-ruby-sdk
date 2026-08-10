# frozen_string_literal: true

require "yaml"

module Antigravity
  class Skill
    attr_reader :name, :description, :instructions, :path

    def initialize(path)
      @path = File.expand_path(path)
      parse_skill_file
    end

    def self.load(path)
      new(path)
    end

    private

    def parse_skill_file
      skill_file = File.join(@path, "SKILL.md")
      raise ArgumentError, "SKILL.md not found at #{@path}" unless File.exist?(skill_file)

      content = File.read(skill_file)
      if content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
        front_matter = YAML.safe_load(Regexp.last_match(1))
        @name = front_matter["name"]
        @description = front_matter["description"]
        @instructions = Regexp.last_match.post_match.strip
      else
        @name = File.basename(@path)
        @description = ""
        @instructions = content.strip
      end
    end
  end
end
