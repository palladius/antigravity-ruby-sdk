# frozen_string_literal: true

# ==========================================================================
# Policy Constants — curated lists of commands, tools, and file patterns.
#
# 🛠️  MAINTAINER NOTES:
#   - One entry per line for easy review in PRs.
#   - Add new entries alphabetically within each group.
#   - Multi-word commands use explicit quotes (no backslash escapes!).
#   - Run `bundle exec rspec spec/antigravity/policy_spec.rb` after edits.
# ==========================================================================

module Antigravity
  class Policy

    # ------------------------------------------------------------------
    # 💀 Catastrophic commands — hard-denied in ALL presets, no exceptions.
    # ------------------------------------------------------------------
    CATASTROPHIC_CMDS = [
      'dd if=/dev/urandom',
      'dd if=/dev/zero',
      '> /dev/sd',
      'halt',
      'mkfs',
      'reboot',
      'rm -rf /*',
      'rm -rf /',
      'rm -rf ~',
      'shutdown',
    ].freeze

    # ------------------------------------------------------------------
    # ⚠️  Risky commands — confirmed in :default, hard-denied in :cautious.
    # Single-word or short patterns that match substring in command_line.
    # ------------------------------------------------------------------
    RISKY_CMDS = [
      'chmod -R 777',
      'chown -R',
      'kill -9',
      'killall',
      'pkill',
      'rm',
    ].freeze

    # ------------------------------------------------------------------
    # 🔥 Destructive git — nuke local changes, rewrite history.
    # Confirmed in :default/:turbo, hard-denied in :cautious/:test.
    # ------------------------------------------------------------------
    DESTRUCTIVE_GIT_CMDS = [
      'git checkout .',
      'git checkout -- .',
      'git clean -fd',
      'git clean -fdx',
      'git push --force',
      'git push -f',
      'git reset --hard',
      'git stash drop',
    ].freeze

    # ------------------------------------------------------------------
    # ✅ Safe read-only shell commands — allowed even in :cautious.
    # ------------------------------------------------------------------
    SAFE_CMDS = %i[
      cat
      cd
      date
      echo
      head
      hostname
      ls
      pwd
      tail
      uname
      wc
      which
      whoami
    ].freeze

    # Safe git subcommands (read-only, no mutations)
    SAFE_GIT_CMDS = [
      'git branch',
      'git diff',
      'git log',
      'git remote',
      'git status',
    ].freeze

    # ------------------------------------------------------------------
    # 🔐 Sensitive file globs — writes to these require confirmation.
    # ------------------------------------------------------------------
    SENSITIVE_FILES = [
      '.env',
      '.env.*',
      '*.key',
      '*.pem',
      '*.secret',
      'id_rsa*',
    ].freeze

    # ------------------------------------------------------------------
    # 📂 Sandbox directories — always writable, even in production.
    # Throwaway / output dirs where agents can freely write.
    # ------------------------------------------------------------------
    SANDBOX_DIRS = [
      'out/*',
      'scratch/*',
    ].freeze

    # ------------------------------------------------------------------
    # 🔧 Tool classifications
    # ------------------------------------------------------------------

    # Read-only harness tools (always safe)
    READONLY_TOOLS = %i[
      find
      grep_search
      list_dir
      read_url_content
      search_web
      view_file
    ].freeze

    # Write harness tools
    WRITE_TOOLS = %i[
      file_edit
      write_to_file
    ].freeze

    # ------------------------------------------------------------------
    # 🗺️  Environment → preset mapping (for Policy.auto)
    # ------------------------------------------------------------------
    PRESET_NAMES = %i[auto cautious default test turbo].freeze

    ENV_MAP = {
      'dev'         => :turbo,
      'development' => :turbo,
      'prod'        => :cautious,
      'production'  => :cautious,
      'staging'     => :default,
      'test'        => :test,
    }.freeze

  end
end
