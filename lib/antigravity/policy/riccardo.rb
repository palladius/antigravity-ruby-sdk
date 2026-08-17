# frozen_string_literal: true

module Antigravity
  class Policy
    # Preset: Riccardo's personal developer policy
    # Designed for maximum productivity with safety guards around secrets and destructive operations.
    def self.riccardo
      define do
        # Protect sensitive files & credentials
        deny :read_file, when: path(%w[.env .env.* ~/.ssh/* ~/.aws/* ~/.config/gcloud/*])
        deny :write_file, when: path(%w[.env .env.* ~/.ssh/* ~/.aws/* ~/.config/gcloud/*])

        # Confirm destructive commands
        confirm :run_command, when: cmd(%w[rm -rf git push --force git reset --hard])

        # Allow common developer tools & read-only ops
        allow :run_command, when: cmd(%w[gcloud kubectl just rv agc chezmoi git ls cat grep bundle rake rspec uv])
        allow :read_file
        allow :write_file, when: path(%w[tmp/* scratch/* out/* log/* docs/* skills/* spec/* lib/*])

        # Confirm anything else
        confirm_all
      end
    end
  end
end
