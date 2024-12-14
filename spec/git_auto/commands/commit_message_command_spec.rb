# frozen_string_literal: true

RSpec.describe GitAuto::Commands::CommitMessageCommand do
  let(:options) { {} }
  let(:settings) { instance_double(GitAuto::Config::Settings) }
  let(:git_service) { instance_double(GitAuto::Services::GitService) }
  let(:ai_service) { instance_double(GitAuto::Services::AIService) }
  let(:history_service) { instance_double(GitAuto::Services::HistoryService) }
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:spinner) { instance_double(TTY::Spinner) }
  let(:validator) { instance_double(GitAuto::Validators::CommitMessageValidator) }
  let(:command) { described_class.new(options) }

  before do
    allow(GitAuto::Config::Settings).to receive(:new).and_return(settings)
    allow(GitAuto::Services::GitService).to receive(:new).and_return(git_service)
    allow(GitAuto::Services::AIService).to receive(:new).and_return(ai_service)
    allow(GitAuto::Services::HistoryService).to receive(:new).and_return(history_service)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(TTY::Spinner).to receive(:new).and_return(spinner)
    allow(GitAuto::Validators::CommitMessageValidator).to receive(:new).and_return(validator)

    # Common settings
    allow(settings).to receive(:get).with(:commit_style).and_return("conventional")
    allow(settings).to receive(:get).with(:show_diff).and_return(false)
    allow(settings).to receive(:get).with(:save_history).and_return(true)

    # Common spinner behavior
    allow(spinner).to receive(:auto_spin)
    allow(spinner).to receive(:success)
    allow(spinner).to receive(:update)

    # Add validation behavior
    allow(validator).to receive(:validate).and_return({ errors: [], warnings: [] })
    allow(validator).to receive(:format_error)
    allow(validator).to receive(:format_warning)

    # Handle analyze_patterns call
    allow(history_service).to receive(:analyze_patterns).and_return({
      scopes: { "ui" => 2, "api" => 1 },
      styles: { "conventional" => 100.0 },
      types: { "feat" => 50.0, "fix" => 25.0 },
      common_phrases: { "add button" => 1 }
    })

    # Add this line to handle save_commit
    allow(history_service).to receive(:save_commit)

    # Suppress output during tests
    allow($stdout).to receive(:puts)
  end

  describe "#execute" do
    let(:repository_status) { { is_clean: false, has_staged_changes: true } }
    let(:diff) { "sample diff" }
    let(:commit_message) { "feat: add new feature" }

    before do
      allow(git_service).to receive(:repository_status).and_return(repository_status)
      allow(git_service).to receive(:get_staged_diff).and_return(diff)
      allow(git_service).to receive(:get_staged_files).and_return(["file1.rb"])
      allow(ai_service).to receive(:generate_commit_message).and_return(commit_message)
      allow(prompt).to receive(:select).and_return(:accept)
      allow(git_service).to receive(:commit)
    end

    it "successfully creates a commit" do
      expect(git_service).to receive(:commit).with(commit_message)
      command.execute
    end

    context "with no staged changes" do
      before do
        # Reset all previous stubs
        RSpec::Mocks.space.proxy_for(git_service).reset

        # Set up the minimal stubs needed
        allow(git_service).to receive(:repository_status).and_return({ is_clean: true, has_staged_changes: false })
        allow($stderr).to receive(:puts)  # Suppress error output
        allow(git_service).to receive(:get_staged_diff).never  # This should never be called
      end

      it "exits with error" do
        expect { command.execute }.to raise_error(SystemExit)
      end
    end

    context "when editing message" do
      before do
        # First prompt returns :edit, second returns :accept
        allow(prompt).to receive(:select).and_return(:edit, :accept)
        allow(command).to receive(:edit_message).and_return("edited message")
        allow(git_service).to receive(:commit).with("edited message")
      end

      it "allows editing the message" do
        command.execute
      end
    end

    context "when generating new message" do
      before do
        allow(prompt).to receive(:select).and_return(:retry, :accept)
      end

      it "generates a new message" do
        expect(ai_service).to receive(:generate_commit_message).twice
        command.execute
      end
    end

    context "when saving to history" do
      it "saves the commit to history" do
        expect(history_service).to receive(:save_commit).with(
          commit_message,
          hash_including(
            files: ["file1.rb"],
            diff_size: be_a(Integer)
          )
        )
        command.execute
      end
    end
  end
end
