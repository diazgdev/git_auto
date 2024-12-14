# frozen_string_literal: true

RSpec.describe GitAuto::Services::GitService do
  let(:service) { described_class.new }
  let(:test_repo_path) { File.join(Dir.tmpdir, "test_repo_#{Time.now.to_i}") }

  before do
    FileUtils.mkdir_p(test_repo_path)
    Dir.chdir(test_repo_path) do
      system("git init")
      system("git config user.name 'Test User'")
      system("git config user.email 'test@example.com'")
    end
  end

  after do
    FileUtils.rm_rf(test_repo_path)
  end

  describe "#get_commit_history" do
    it "returns commit history with specified limit" do
      Dir.chdir(test_repo_path) do
        system("touch test.txt")
        system("git add test.txt")
        system("git commit -m 'test commit'")
        commits = service.get_commit_history(5)
        expect(commits).to be_an(Array)
        expect(commits.length).to be <= 5
      end
    end

    it "includes required commit information" do
      Dir.chdir(test_repo_path) do
        system("touch test.txt")
        system("git add test.txt")
        system("git commit -m 'test commit'")
        commits = service.get_commit_history(1)
        if commits.any?
          commit = commits.first
          expect(commit).to include(:hash, :subject, :author, :date)
        end
      end
    end

    it "raises error when not in a git repository" do
      Dir.chdir(Dir.tmpdir) do
        expect { service.get_commit_history }.to raise_error(GitAuto::Services::GitService::Error)
      end
    end
  end

  describe "#get_staged_diff" do
    it "returns diff of staged changes" do
      Dir.chdir(test_repo_path) do
        File.write("test.txt", "initial content")
        system("git add test.txt")
        diff = service.get_staged_diff
        expect(diff).to include("test.txt")
      end
    end

    it "returns empty string when no staged changes" do
      Dir.chdir(test_repo_path) do
        # Ensure clean state
        system("git add .")
        system("git commit -m 'clean state' --allow-empty")
        expect(service.get_staged_diff).to eq("")
      end
    end
  end

  describe "#repository_status" do
    it "returns repository status information" do
      Dir.chdir(test_repo_path) do
        status = service.repository_status
        expect(status).to include(
          :has_staged_changes,
          :is_clean,
          :has_commits
        )
      end
    end
  end
end
