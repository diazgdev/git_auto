# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitAuto::Services::HistoryService do
  let(:settings) { GitAuto::Config::Settings.new }
  let(:service) { described_class.new }
  let(:history_file) { described_class::HISTORY_FILE }
  let(:test_commit) { { message: "feat(test): add new feature", timestamp: Time.now.iso8601 } }

  before do
    # Ensure clean state
    FileUtils.rm_f(history_file)
  end

  after do
    FileUtils.rm_f(history_file)
  end

  describe "#save_commit" do
    it "saves commit to history file" do
      service.save_commit(test_commit[:message])
      history = JSON.parse(File.read(history_file), symbolize_names: true)
      expect(history.first[:message]).to eq(test_commit[:message])
    end

    it "maintains max 10 entries" do
      15.times { |i| service.save_commit("commit #{i}") }
      history = JSON.parse(File.read(history_file), symbolize_names: true)
      expect(history.length).to eq(10)
      expect(history.first[:message]).to eq("commit 14") # Most recent
      expect(history.last[:message]).to eq("commit 5") # Oldest
    end

    it "includes metadata when provided" do
      metadata = { files: ["test.rb"], diff_size: 100 }
      service.save_commit(test_commit[:message], metadata)
      history = JSON.parse(File.read(history_file), symbolize_names: true)
      expect(history.first[:metadata]).to eq(metadata)
    end

    it "handles empty commit messages" do
      service.save_commit("")
      history = JSON.parse(File.read(history_file), symbolize_names: true)
      expect(history.first[:message]).to eq("")
    end

    it "handles special characters in commit messages" do
      message = "feat: add support for 🚀 emojis & special chars"
      service.save_commit(message)
      history = JSON.parse(File.read(history_file), symbolize_names: true)
      expect(history.first[:message]).to eq(message)
    end
  end

  describe "#get_recent_commits" do
    before do
      5.times { |i| service.save_commit("commit #{i}") }
    end

    it "returns all commits when no limit is specified" do
      commits = service.get_recent_commits
      expect(commits.length).to eq(5)
    end

    it "returns limited number of commits when limit is specified" do
      commits = service.get_recent_commits(2)
      expect(commits.length).to eq(2)
      expect(commits.first[:message]).to eq("commit 4") # Most recent
    end
  end

  describe "#analyze_patterns" do
    before do
      commits = [
        "feat(ui): add button",
        "fix(api): resolve timeout",
        "feat(ui): update styles",
        "chore(deps): update dependencies"
      ]
      commits.each { |msg| service.save_commit(msg) }
    end

    it "analyzes commit styles" do
      patterns = service.analyze_patterns
      expect(patterns[:styles]["conventional"]).to eq(100.0)
    end

    it "analyzes commit scopes" do
      patterns = service.analyze_patterns
      expect(patterns[:scopes]).to include("ui" => 2, "api" => 1)
    end

    it "analyzes commit types" do
      patterns = service.analyze_patterns
      expect(patterns[:types]).to include(
        "feat" => 50.0,
        "fix" => 25.0,
        "chore" => 25.0
      )
    end

    it "analyzes common phrases" do
      patterns = service.analyze_patterns
      expect(patterns[:common_phrases]).to include("add button" => 1)
    end

    it "respects the limit parameter" do
      patterns = service.analyze_patterns(2)
      expect(patterns[:scopes].keys.length).to be <= 2
    end

    it "handles empty history" do
      File.write(history_file, "[]")
      patterns = service.analyze_patterns
      expect(patterns).to eq({})
    end
  end
end
