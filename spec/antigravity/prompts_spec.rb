# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workflow Maintenance Prompts" do
  let(:prompts_dir) { File.expand_path("../../docs/prompts", __dir__) }

  let(:expected_prompts) do
    %w[
      daily-ai-job.md
      search-for-vulnerabilities.md
      verify-functionality-and-docs-in-sync.md
      assert-ruby-elegance-and-beauty-are-preserved.md
    ]
  end

  it "contains all required workflow prompt files" do
    expected_prompts.each do |prompt_file|
      path = File.join(prompts_dir, prompt_file)
      expect(File.exist?(path)).to be(true), "Expected #{prompt_file} to exist in docs/prompts/"
      content = File.read(path)
      expect(content).to include("# Prompt:")
      expect(content.bytesize).to be > 100
    end
  end
end
