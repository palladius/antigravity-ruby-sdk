# frozen_string_literal: true

module Antigravity
  module Jev
    # Read-only lookup of KEY=value pairs: ENV first, then a list of .env files.
    # Never writes anything (the user's .env files are sacred).
    module KeyFinder
      module_function

      # $GIC if exported, else the conventional ~/git/gic checkout.
      def gic_dir
        ENV['GIC'] && !ENV['GIC'].empty? ? ENV['GIC'] : File.expand_path('~/git/gic')
      end

      def default_env_files
        [File.join(gic_dir, '.env'), File.expand_path('.env')]
      end

      def lookup(var, files: default_env_files)
        from_env = ENV[var]
        return from_env if from_env && !from_env.empty?

        files.each do |path|
          value = read_var(path, var)
          return value if value
        end
        nil
      end

      def read_var(path, var)
        return nil unless File.file?(path)

        File.read(path)[/^\s*(?:export\s+)?#{Regexp.escape(var)}=['"]?([^'"\s]+)/, 1]
      rescue SystemCallError
        nil
      end
    end
  end
end
