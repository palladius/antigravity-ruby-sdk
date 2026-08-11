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
