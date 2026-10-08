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

  it 'accepts --mock flag for offline testing' do
    out, status = Open3.capture2e(bin_path, '--mock', 'guard', 'ls -la')
    expect(status.success?).to be true
    expect(out).to include('APPROVED')
  end

  it 'accepts --yolo and --yes flags to auto-confirm unsure commands' do
    out, status = Open3.capture2e(bin_path, '--mock', '--yolo', 'exec', 'cat .env')
    expect(status.success?).to be true
    expect(out).not_to include('Execute this command?')
  end

  it 'accepts --model to force a model and skip JEV routing' do
    out, status = Open3.capture2e(bin_path, '--mock', '--model', 'gemini-3.6-flash', 'ciao come stai')
    expect(status.success?).to be true
    expect(out).to include('MODEL: gemini-3.6-flash (forced')
    expect(out).not_to include('ROUTED')
  end
end
