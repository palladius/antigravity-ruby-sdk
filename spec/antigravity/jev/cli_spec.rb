# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'CLI bin/jevity and bin/rujev' do
  let(:bin_path) { File.expand_path('../../../bin/jevity', __dir__) }
  let(:rujev_path) { File.expand_path('../../../bin/rujev', __dir__) }

  it 'displays help message with --help' do
    out, status = Open3.capture2e(bin_path, '--help')
    expect(status.success?).to be true
    expect(out).to include('jevity')
    expect(out).to include('Usage:')
  end

  it 'displays version with --version' do
    out, status = Open3.capture2e(bin_path, '--version')
    expect(status.success?).to be true
    expect(out).to include(Antigravity::VERSION)
  end

  it 'symlink bin/rujev exists and executes bin/jevity' do
    out, status = Open3.capture2e(rujev_path, '--help')
    expect(status.success?).to be true
    expect(out).to include('Usage:')
  end

  it 'validates --folder directory exists' do
    out, status = Open3.capture2e(bin_path, '--folder', '/nonexistent_folder_xyz_123', '--help')
    expect(status.success?).to be false
    expect(out).to include('directory not found')
  end

  it 'accepts valid --folder option' do
    out, status = Open3.capture2e(bin_path, '--folder', '/tmp', '--version')
    expect(status.success?).to be true
    expect(out).to include(Antigravity::VERSION)
  end
end
