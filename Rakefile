# frozen_string_literal: true

require "rspec/core/rake_task"
require "bundler/gem_tasks"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :harness do
  desc "Fetch or verify localharness Go binary for local platform"
  task :fetch do
    puts "🔍 Checking for localharness binary..."
    harness_path = File.expand_path("~/.antigravity/bin/localharness")
    if File.exist?(harness_path)
      puts "✅ Found localharness at #{harness_path}"
    else
      puts "ℹ️ localharness not found at #{harness_path}. Installing/verifying..."
      # Create bin directory if needed
      FileUtils.mkdir_p(File.dirname(harness_path))
      puts "💡 Ensure `google-antigravity` wheel or localharness is installed."
    end
  end
end
