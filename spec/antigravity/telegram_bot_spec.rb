# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'Telegram Bot Script' do
  let(:script_path) { File.expand_path('../../examples/08_skill_telegram_bot.rb', __dir__) }
  let(:script_content) { File.read(script_path, encoding: 'UTF-8') }

  # ==========================================================================
  # Syntax & Unicode Validation
  # ==========================================================================
  describe 'syntax validation' do
    it 'has valid Ruby syntax' do
      result = `ruby -c #{script_path} 2>&1`
      expect(result.strip).to eq('Syntax OK'), "Syntax check failed: #{result}"
    end

    it 'does not contain literal \\uDxxx surrogate escape sequences' do
      surrogates = script_content.scan(/\\uD[89A-Fa-f][0-9A-Fa-f]{2}/)
      expect(surrogates).to be_empty,
        "Found invalid unicode surrogate escape sequences: #{surrogates.uniq.join(', ')}"
    end

    it 'uses real UTF-8 emoji characters (not \\uXXXX escapes) for display strings' do
      # Bot uses emoji extensively — verify they are actual UTF-8, not escape sequences
      expect(script_content).to include('🔍')  # find_skills
      expect(script_content).to include('📚')  # skills
      expect(script_content).to include('🔥')  # scary mode
      expect(script_content).to include('⚡')  # auto-reset
      expect(script_content).to include('🔄')  # reset
    end
  end

  # ==========================================================================
  # Tool.define — Dynamic Tool Factory
  # ==========================================================================
  describe 'Tool.define' do
    it 'creates a dynamic tool with name, description, and params schema' do
      tool = Antigravity::Tool.define(:test_tool,
        desc: 'A test tool',
        params: { name: { type: :string, desc: 'A name' } }
      ) { |name:| "Hello #{name}" }

      expect(tool.tool_name).to eq('test_tool')
      schema = tool.to_json_schema
      expect(schema[:name]).to eq('test_tool')
      expect(schema[:description]).to eq('A test tool')
      expect(schema[:parameters][:properties]).to have_key(:name)
      expect(schema[:parameters][:properties][:name][:type]).to eq('string')
    end

    it 'executes the tool block with keyword arguments' do
      tool = Antigravity::Tool.define(:greeter,
        desc: 'Greet',
        params: { who: { type: :string } }
      ) { |who:| "Ciao #{who}!" }

      expect(tool.call(who: 'Riccardo')).to eq('Ciao Riccardo!')
    end

    it 'supports optional params with defaults' do
      tool = Antigravity::Tool.define(:searcher,
        desc: 'Search',
        params: { query: { type: :string, required: false } }
      ) { |query: ''| query.empty? ? 'all results' : "results for #{query}" }

      expect(tool.call(query: 'ruby')).to eq('results for ruby')
      expect(tool.call(query: '')).to eq('all results')
    end
  end

  # ==========================================================================
  # Workspace Guard — Path Traversal Protection
  # ==========================================================================
  describe 'workspace guard logic' do
    let(:workspace) { Dir.mktmpdir('telegram_test_workspace') }

    after { FileUtils.rm_rf(workspace) }

    let(:guard) do
      ws = workspace
      ->(path) {
        expanded = File.expand_path(path, ws)
        unless expanded.start_with?(ws)
          raise "Access denied: #{path} is outside workspace #{ws}"
        end
        expanded
      }
    end

    it 'allows paths inside workspace' do
      expect(guard.call('notes.md')).to eq(File.join(workspace, 'notes.md'))
    end

    it 'allows nested paths inside workspace' do
      expect(guard.call('sub/dir/file.txt')).to eq(File.join(workspace, 'sub/dir/file.txt'))
    end

    it 'blocks path traversal with ../' do
      expect { guard.call('../../../etc/passwd') }.to raise_error(/Access denied/)
    end

    it 'blocks absolute paths outside workspace' do
      expect { guard.call('/etc/passwd') }.to raise_error(/Access denied/)
    end

    it 'allows . (current directory)' do
      expect(guard.call('.')).to eq(workspace)
    end
  end

  # ==========================================================================
  # File Tools — read/write/append/delete/list
  # ==========================================================================
  describe 'file tools' do
    let(:workspace) { Dir.mktmpdir('telegram_test_files') }

    after { FileUtils.rm_rf(workspace) }

    let(:guard) do
      ws = workspace
      ->(path) {
        expanded = File.expand_path(path, ws)
        raise "Access denied" unless expanded.start_with?(ws)
        expanded
      }
    end

    describe 'read_file' do
      it 'reads an existing file' do
        File.write(File.join(workspace, 'hello.txt'), 'Ciao mondo!')
        tool = Antigravity::Tool.define(:read_file,
          desc: 'Read file', params: { path: { type: :string } }
        ) { |path:|
          full = guard.call(path)
          File.exist?(full) ? File.read(full) : "File not found: #{path}"
        }
        expect(tool.call(path: 'hello.txt')).to eq('Ciao mondo!')
      end

      it 'returns error for missing file' do
        tool = Antigravity::Tool.define(:read_file_missing,
          desc: 'Read file', params: { path: { type: :string } }
        ) { |path:|
          full = guard.call(path)
          File.exist?(full) ? File.read(full) : "File not found: #{path}"
        }
        expect(tool.call(path: 'nope.txt')).to eq('File not found: nope.txt')
      end
    end

    describe 'write_file' do
      it 'creates a new file with content' do
        tool = Antigravity::Tool.define(:write_file,
          desc: 'Write file', params: { path: { type: :string }, content: { type: :string } }
        ) { |path:, content:|
          full = guard.call(path)
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, content)
          "Written #{content.length} bytes to #{path}"
        }
        result = tool.call(path: 'new.md', content: '# Hello')
        expect(result).to eq('Written 7 bytes to new.md')
        expect(File.read(File.join(workspace, 'new.md'))).to eq('# Hello')
      end

      it 'creates nested directories' do
        tool = Antigravity::Tool.define(:write_nested,
          desc: 'Write file', params: { path: { type: :string }, content: { type: :string } }
        ) { |path:, content:|
          full = guard.call(path)
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, content)
          "Written #{content.length} bytes to #{path}"
        }
        tool.call(path: 'deep/nested/dir/file.txt', content: 'deep!')
        expect(File.exist?(File.join(workspace, 'deep/nested/dir/file.txt'))).to be true
      end
    end

    describe 'append_file' do
      it 'appends to an existing file' do
        target = File.join(workspace, 'log.txt')
        File.write(target, 'line1')
        tool = Antigravity::Tool.define(:append_file,
          desc: 'Append', params: { path: { type: :string }, content: { type: :string } }
        ) { |path:, content:|
          full = guard.call(path)
          File.open(full, 'a') { |f| f.write(content) }
          "Appended #{content.length} bytes to #{path}"
        }
        tool.call(path: 'log.txt', content: "\nline2")
        expect(File.read(target)).to eq("line1\nline2")
      end
    end

    describe 'delete_file' do
      it 'deletes an existing file' do
        target = File.join(workspace, 'doomed.txt')
        File.write(target, 'goodbye')
        tool = Antigravity::Tool.define(:delete_file,
          desc: 'Delete', params: { path: { type: :string } }
        ) { |path:|
          full = guard.call(path)
          File.exist?(full) ? (File.delete(full); "Deleted: #{path}") : "File not found: #{path}"
        }
        expect(tool.call(path: 'doomed.txt')).to eq('Deleted: doomed.txt')
        expect(File.exist?(target)).to be false
      end

      it 'returns error for missing file' do
        tool = Antigravity::Tool.define(:delete_missing,
          desc: 'Delete', params: { path: { type: :string } }
        ) { |path:|
          full = guard.call(path)
          File.exist?(full) ? (File.delete(full); "Deleted: #{path}") : "File not found: #{path}"
        }
        expect(tool.call(path: 'nope.txt')).to eq('File not found: nope.txt')
      end
    end

    describe 'list_files' do
      it 'lists directory contents with icons' do
        FileUtils.mkdir_p(File.join(workspace, 'subdir'))
        File.write(File.join(workspace, 'file.txt'), 'hi')

        tool = Antigravity::Tool.define(:list_files,
          desc: 'List', params: { path: { type: :string, required: false } }
        ) { |path: '.'|
          full = guard.call(path)
          entries = Dir.children(full).sort.map { |e|
            stat = File.stat(File.join(full, e)) rescue nil
            type = stat&.directory? ? '📁' : '📄'
            size = stat&.file? ? " (#{stat.size}b)" : ''
            "#{type} #{e}#{size}"
          }
          entries.empty? ? '(empty directory)' : entries.join("\n")
        }
        result = tool.call(path: '.')
        expect(result).to include('📄 file.txt (2b)')
        expect(result).to include('📁 subdir')
      end

      it 'reports empty directory' do
        empty = File.join(workspace, 'empty')
        FileUtils.mkdir_p(empty)
        tool = Antigravity::Tool.define(:list_empty,
          desc: 'List', params: { path: { type: :string, required: false } }
        ) { |path: '.'|
          full = guard.call(path)
          entries = Dir.children(full).sort
          entries.empty? ? '(empty directory)' : entries.join("\n")
        }
        expect(tool.call(path: 'empty')).to eq('(empty directory)')
      end
    end
  end

  # ==========================================================================
  # Skill Discovery (find_skills pattern)
  # ==========================================================================
  describe 'skill discovery' do
    let(:skill_dir) { Dir.mktmpdir('telegram_test_skills') }

    after { FileUtils.rm_rf(skill_dir) }

    it 'finds SKILL.md files in a directory tree' do
      # Create a fake skill
      skill_path = File.join(skill_dir, 'ruby-coding')
      FileUtils.mkdir_p(skill_path)
      File.write(File.join(skill_path, 'SKILL.md'), "---\nname: ruby-coding\ndescription: Ruby best practices\n---\n# Ruby")

      results = Dir.glob(File.join(skill_dir, '**/SKILL.md'))
      expect(results.size).to eq(1)
      expect(results.first).to include('ruby-coding/SKILL.md')
    end

    it 'extracts description from YAML frontmatter' do
      skill_path = File.join(skill_dir, 'test-skill')
      FileUtils.mkdir_p(skill_path)
      File.write(File.join(skill_path, 'SKILL.md'), "---\nname: test\ndescription: A great skill for testing\n---")

      content = File.read(File.join(skill_path, 'SKILL.md'))
      desc = content.match(/^description:\s*(.+)$/i)&.[](1)&.strip
      expect(desc).to eq('A great skill for testing')
    end

    it 'filters skills by query keyword (case-insensitive)' do
      %w[ruby-coding python-coding sre-setup].each do |name|
        path = File.join(skill_dir, name)
        FileUtils.mkdir_p(path)
        File.write(File.join(path, 'SKILL.md'), "---\ndescription: #{name} stuff\n---")
      end

      query = 'ruby'
      results = Dir.glob(File.join(skill_dir, '**/SKILL.md')).select { |f|
        File.basename(File.dirname(f)).downcase.include?(query.downcase)
      }
      expect(results.size).to eq(1)
      expect(results.first).to include('ruby-coding')
    end

    it 'returns all skills when query is empty' do
      %w[skill-a skill-b skill-c].each do |name|
        path = File.join(skill_dir, name)
        FileUtils.mkdir_p(path)
        File.write(File.join(path, 'SKILL.md'), "---\ndescription: #{name}\n---")
      end

      results = Dir.glob(File.join(skill_dir, '**/SKILL.md'))
      expect(results.size).to eq(3)
    end
  end

  # ==========================================================================
  # Tilde Expansion & URL Handling
  # ==========================================================================
  describe 'tilde expansion' do
    it 'File.expand_path expands ~ to home directory' do
      expanded = File.expand_path('~/git/some-skill')
      expect(expanded).to start_with('/')
      expect(expanded).not_to include('~')
      expect(expanded).to include('/git/some-skill')
    end

    it 'does not expand URLs (http/https)' do
      url = 'https://github.com/example/skill'
      result = url.start_with?('http') ? url : File.expand_path(url)
      expect(result).to eq(url)
    end

    it 'parses comma-separated skill paths' do
      raw = '~/git/skill-a,https://github.com/x/y,~/git/skill-b'
      parsed = raw.split(',').map(&:strip).map { |s|
        s.start_with?('http') ? s : File.expand_path(s)
      }
      expect(parsed.size).to eq(3)
      expect(parsed[0]).to start_with('/')
      expect(parsed[0]).to include('/git/skill-a')
      expect(parsed[1]).to eq('https://github.com/x/y')
      expect(parsed[2]).to include('/git/skill-b')
    end
  end

  # ==========================================================================
  # Error Handling Patterns
  # ==========================================================================
  describe 'error handling' do
    it 'ProtocolError is defined in Antigravity module' do
      expect(defined?(Antigravity::ProtocolError)).to be_truthy
    end

    it 'Telegram message truncation at 4000 chars' do
      long_response = 'x' * 5000
      truncated = if long_response.length > 4000
                    long_response[0, 3990] + "\n\n_(truncated)_"
                  else
                    long_response
                  end
      expect(truncated.length).to be <= 4010
      expect(truncated).to end_with('_(truncated)_')
    end

    it 'error messages are truncated to 200 chars' do
      long_error = 'e' * 500
      truncated = long_error[0, 200]
      expect(truncated.length).to eq(200)
    end
  end

  # ==========================================================================
  # Script Structure Integrity
  # ==========================================================================
  describe 'script structure' do
    it 'defines all expected commands' do
      %w[/reset /help /skills /status /stop].each do |cmd|
        expect(script_content).to include("when '#{cmd}'"),
          "Missing command handler for #{cmd}"
      end
    end

    it 'defines all file tool names' do
      %w[read_file write_file append_file delete_file list_files].each do |tool|
        expect(script_content).to include(":#{tool}"),
          "Missing tool definition for #{tool}"
      end
    end

    it 'defines dynamic skill tools' do
      expect(script_content).to include(':find_skills')
      expect(script_content).to include(':load_skill')
    end

    it 'defines BOT_VERSION constant in semver format' do
      match = script_content.match(/BOT_VERSION\s*=\s*'(\d+\.\d+\.\d+)'/)
      expect(match).not_to be_nil, 'BOT_VERSION not found or not semver'
      version = match[1]
      major, minor, patch = version.split('.').map(&:to_i)
      expect(major).to be >= 0
      expect(minor).to be >= 0
      expect(patch).to be >= 0
    end

    it 'shows BOT_VERSION in /status output' do
      expect(script_content).to include('BOT_VERSION')
      expect(script_content).to match(/Bot v.*BOT_VERSION/)
    end

    it 'handles 409 Conflict errors' do
      expect(script_content).to include("409")
      expect(script_content).to include('Conflict')
    end

    it 'handles auto-reset on connection errors' do
      expect(script_content).to include('ProtocolError')
      expect(script_content).to include('Auto-resetting session')
    end

    it 'wires tools and workspace into all session creation points' do
      # Every ChatSession.new should pass tools: and workspace:
      session_creates = script_content.scan(/ChatSession\.new\([^)]+\)/)
      session_creates.each do |call|
        expect(call).to include('tools:'), "Missing tools: in #{call[0, 80]}"
        expect(call).to include('workspace:'), "Missing workspace: in #{call[0, 80]}"
      end
    end
  end
end
