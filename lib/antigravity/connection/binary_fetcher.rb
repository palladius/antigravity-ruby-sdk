# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tmpdir'
require 'net/http'
require 'json'
require 'uri'

module Antigravity
  module Connection
    # Downloads and extracts the localharness binary from the official
    # google-antigravity PyPI wheel. Used when the binary isn't already
    # installed via Antigravity.app or a manual setup.
    module BinaryFetcher
      PYPI_PACKAGE = 'google-antigravity'
      INSTALL_DIR  = File.expand_path('~/.antigravity/bin')
      BINARY_NAME  = 'language_server'

      # Platform mapping: Ruby's RUBY_PLATFORM -> PyPI wheel platform tag
      PLATFORM_MAP = {
        /darwin.*arm/i   => 'macosx_11_0_arm64',
        /darwin.*x86/i   => 'macosx_10_15_x86_64',
        /darwin/i        => 'macosx_11_0_arm64',    # default macOS = ARM
        /linux.*x86_64/i => 'manylinux2014_x86_64',
        /linux.*aarch/i  => 'manylinux2014_aarch64',
      }.freeze

      class << self
        # Fetch and install the binary. Returns the installed path.
        # @param quiet [Boolean] suppress progress output
        # @return [String] path to the installed binary
        def fetch!(quiet: false)
          platform = detect_platform
          say("🔍 Detecting platform: #{platform}", quiet: quiet)

          # Step 1: Find the wheel URL from PyPI
          say("📡 Querying PyPI for #{PYPI_PACKAGE}...", quiet: quiet)
          wheel_url = find_wheel_url(platform)

          # Step 2: Download the wheel
          say("⏳ Downloading binary... this will take some time (~50MB wheel)", quiet: quiet)
          wheel_path = download_wheel(wheel_url, quiet: quiet)

          # Step 3: Extract the binary
          say("📦 Extracting localharness binary...", quiet: quiet)
          binary_path = extract_binary(wheel_path)

          # Step 4: Make executable
          FileUtils.chmod(0o755, binary_path)
          say("✅ Installed localharness at #{binary_path}", quiet: quiet)

          binary_path
        ensure
          # Clean up temp wheel
          FileUtils.rm_f(wheel_path) if wheel_path && File.exist?(wheel_path.to_s)
        end

        # Check if the binary is already installed via fetch
        def installed?
          path = File.join(INSTALL_DIR, BINARY_NAME)
          File.executable?(path)
        end

        def installed_path
          File.join(INSTALL_DIR, BINARY_NAME)
        end

        private

        def detect_platform
          PLATFORM_MAP.each do |pattern, tag|
            return tag if RUBY_PLATFORM.match?(pattern)
          end
          raise HarnessNotFoundError,
            "Unsupported platform: #{RUBY_PLATFORM}. Cannot auto-download localharness."
        end

        def find_wheel_url(platform)
          uri = URI("https://pypi.org/pypi/#{PYPI_PACKAGE}/json")
          response = Net::HTTP.get(uri)
          data = JSON.parse(response)

          # Find latest version's wheel for our platform
          urls = data['urls'] || []
          wheel = urls.find { |u| u['filename']&.include?(platform) && u['filename']&.end_with?('.whl') }

          unless wheel
            # Try all versions for the platform
            versions = data['releases']&.keys&.sort_by { |v| Gem::Version.new(v) rescue v }&.reverse
            versions&.each do |ver|
              files = data.dig('releases', ver) || []
              wheel = files.find { |u| u['filename']&.include?(platform) && u['filename']&.end_with?('.whl') }
              break if wheel
            end
          end

          raise HarnessNotFoundError,
            "No wheel found for platform #{platform} on PyPI. Install Antigravity.app manually." unless wheel

          wheel['url']
        end

        def download_wheel(url, quiet: false)
          dest = File.join(Dir.tmpdir, "antigravity-wheel-#{$$}.whl")
          uri = URI(url)

          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            request = Net::HTTP::Get.new(uri)
            http.request(request) do |response|
              total = response['content-length']&.to_i
              downloaded = 0

              File.open(dest, 'wb') do |f|
                response.read_body do |chunk|
                  f.write(chunk)
                  downloaded += chunk.bytesize
                  if total && total > 0 && !quiet
                    pct = (downloaded * 100.0 / total).round(1)
                    print "\r  ⏳ #{pct}% (#{(downloaded / 1024.0 / 1024).round(1)} MB / #{(total / 1024.0 / 1024).round(1)} MB)"
                  end
                end
              end
              puts unless quiet
            end
          end

          dest
        end

        def extract_binary(wheel_path)
          FileUtils.mkdir_p(INSTALL_DIR)

          # Wheels are just ZIP files. Extract the binary.
          # Look for: google/antigravity/bin/localharness (or language_server)
          extract_dir = Dir.mktmpdir('agy-extract-')
          system('unzip', '-q', '-o', wheel_path, '-d', extract_dir)

          # Search for the binary inside
          candidates = Dir.glob("#{extract_dir}/**/language_server") +
                       Dir.glob("#{extract_dir}/**/localharness")

          binary = candidates.find { |f| File.file?(f) && !File.directory?(f) }

          unless binary
            FileUtils.rm_rf(extract_dir)
            raise HarnessNotFoundError,
              "Could not find localharness binary inside the wheel. Contents: #{Dir.glob("#{extract_dir}/**/*").join(', ')}"
          end

          dest_path = File.join(INSTALL_DIR, BINARY_NAME)
          FileUtils.cp(binary, dest_path)
          FileUtils.rm_rf(extract_dir)
          dest_path
        end

        def say(msg, quiet: false)
          $stderr.puts msg unless quiet
        end
      end
    end
  end
end
