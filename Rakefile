# frozen_string_literal: true

require "rspec/core/rake_task"
require "bundler/gem_tasks"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :harness do
  desc "Check if localharness binary is available"
  task :check do
    require "antigravity"
    begin
      path = Antigravity::Connection::LocalConnection.find_binary!
      puts "✅ localharness found at: #{path}"
    rescue Antigravity::HarnessNotFoundError => e
      puts "❌ #{e.message}"
      exit 1
    end
  end

  desc "Download localharness binary from PyPI wheel"
  task :fetch do
    require "antigravity"
    if Antigravity::Connection::BinaryFetcher.installed?
      puts "✅ Already installed at #{Antigravity::Connection::BinaryFetcher.installed_path}"
    else
      puts "⏳ Downloading localharness binary from PyPI... this will take some time."
      path = Antigravity::Connection::BinaryFetcher.fetch!
      puts "✅ Installed at #{path}"
    end
  end

  desc "Force re-download localharness binary"
  task :update do
    require "antigravity"
    require "fileutils"
    old = Antigravity::Connection::BinaryFetcher.installed_path
    FileUtils.rm_f(old)
    puts "⏳ Re-downloading localharness binary from PyPI... this will take some time."
    path = Antigravity::Connection::BinaryFetcher.fetch!
    puts "✅ Updated at #{path}"
  end
end

namespace :antigravity do
  desc "Import permissions from Gemini config.json and save DRY Ruby DSL (args: path, limit, output_file)"
  task :policy_import, [:path, :limit, :output_file] do |_t, args|
    require "antigravity"
    config_path = args[:path] || "~/.gemini/config/config.json"
    limit = args[:limit] && !args[:limit].to_s.empty? ? args[:limit].to_i : nil
    output_file = args[:output_file] || "out/sample_policy.rb"

    puts "🛡️ Importing Gemini CLI policy from: #{config_path}#{limit ? " (limit: #{limit})" : ''}"
    policy = Antigravity::Policy.from_gemini_config(config_path, limit: limit)
    saved_path = policy.save_ruby_dsl(output_file)

    puts "\n" + policy.to_ruby_dsl
    puts "\n💾 Saved Ruby policy to: #{saved_path}"
  end
end
