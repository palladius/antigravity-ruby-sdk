# frozen_string_literal: true

require "fileutils"

module Antigravity
  # Resolves skill paths from various inputs: single skill dir, container dir,
  # or GitHub URL. Returns expanded absolute paths to skill directories.
  #
  # Resolution logic:
  #   1. Path contains SKILL.md -> single skill
  #   2. Path has a skills/ subfolder -> discover children with SKILL.md
  #   3. Path children have SKILL.md -> flat container discovery
  #   4. GitHub URL -> clone/cache then resolve locally
  #
  # Spec compliance: https://agentskills.io/specification
  class SkillResolver
    GITHUB_URL_PATTERN = %r{\Ahttps?://github\.com/}i
    CACHE_DIR = File.expand_path('~/.antigravity/cache/ruby-sdk/skills')

    # Resolve a path or URL to an array of valid skill directory paths.
    # @param path_or_url [String] local path or GitHub URL
    # @return [Array<String>] expanded absolute paths to skill directories
    def self.resolve(path_or_url)
      path_or_url = path_or_url.to_s.strip

      if github_url?(path_or_url)
        resolve_github(path_or_url)
      else
        resolve_local(path_or_url)
      end
    end

    # Discover all skill directories inside a container path.
    # Checks for skills/ subfolder first, then scans children directly.
    # @param container_path [String] path to scan for skills
    # @return [Array<String>] sorted list of skill directory paths
    def self.discover(container_path)
      expanded = File.expand_path(container_path)
      return [] unless File.directory?(expanded)

      # Check for skills/ subfolder first (convention from agentskills.io)
      skills_subdir = File.join(expanded, 'skills')
      scan_dir = File.directory?(skills_subdir) ? skills_subdir : expanded

      Dir.children(scan_dir)
         .map { |child| File.join(scan_dir, child) }
         .select { |child_path| skill_dir?(child_path) }
         .sort
    end

    # Check if a directory is a valid skill (contains SKILL.md).
    # @param path [String] directory path to check
    # @return [Boolean]
    def self.skill_dir?(path)
      File.directory?(path) && File.exist?(File.join(path, 'SKILL.md'))
    end

    # Check if a string looks like a GitHub URL.
    # @param str [String]
    # @return [Boolean]
    def self.github_url?(str)
      str.match?(GITHUB_URL_PATTERN)
    end

    class << self
      private

      def resolve_local(path)
        expanded = File.expand_path(path)
        raise ArgumentError, "Skill path does not exist: #{expanded}" unless File.exist?(expanded)
        raise ArgumentError, "Skill path is not a directory: #{expanded}" unless File.directory?(expanded)

        # Case 1: Direct skill dir (has SKILL.md)
        return [expanded] if skill_dir?(expanded)

        # Case 2 & 3: Container dir -- discover children
        discovered = discover(expanded)
        return discovered unless discovered.empty?

        raise ArgumentError, "No skills found at #{expanded}. Expected SKILL.md or a skills/ subfolder."
      end

      # Parse a GitHub URL into components.
      # Supports:
      #   https://github.com/org/repo
      #   https://github.com/org/repo/tree/main/skills/my-skill
      #   https://github.com/org/repo/tree/main/skills
      #
      # Returns [org, repo, subpath_or_nil]
      def parse_github_url(url)
        # Strip trailing slash
        url = url.chomp('/')

        case url
        when %r{github\.com/([^/]+)/([^/]+)/tree/[^/]+/(.+)}
          # URL with tree/branch/subpath
          [Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)]
        when %r{github\.com/([^/]+)/([^/]+)(?:\.git)?/?$}
          # Bare repo URL
          [Regexp.last_match(1), Regexp.last_match(2), nil]
        else
          raise ArgumentError, "Cannot parse GitHub URL: #{url}"
        end
      end

      def resolve_github(url)
        org, repo, subpath = parse_github_url(url)
        local_repo = clone_or_update(org, repo)

        # Resolve subpath within the cloned repo
        target = subpath ? File.join(local_repo, subpath) : local_repo
        resolve_local(target)
      end

      # Clone (or update) a GitHub repo into the cache.
      # Returns the local path to the cloned repo.
      def clone_or_update(org, repo)
        cache_path = File.join(CACHE_DIR, org, repo)

        if File.directory?(File.join(cache_path, '.git'))
          # Already cloned -- pull latest
          system('git', '-C', cache_path, 'pull', '--ff-only', '--quiet',
                 out: File::NULL, err: File::NULL)
        else
          # Fresh clone
          FileUtils.mkdir_p(File.dirname(cache_path))
          clone_url = "https://github.com/#{org}/#{repo}.git"
          success = system('git', 'clone', '--depth=1', '--quiet', clone_url, cache_path,
                           out: File::NULL, err: File::NULL)
          raise "Failed to clone #{clone_url}. Check the URL and your network." unless success
        end

        cache_path
      end
    end
  end
end
