# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitAuto::Services::AIService do
  let(:diff) do
    <<~DIFF
      diff --git a/lib/example.rb b/lib/example.rb
      index abc..def 100644
      --- a/lib/example.rb
      +++ b/lib/example.rb
      @@ -1,3 +1,3 @@
      -old line
      +new line
    DIFF
  end

  let(:settings) { instance_double(GitAuto::Config::Settings) }
  let(:service) { described_class.new(settings) }

  before do
    allow(settings).to receive(:get).with(:openai_api_key).and_return("sk-1234567890")
    allow(settings).to receive(:get).with(:anthropic_api_key).and_return("anthropic-key-1234567890")
    allow(settings).to receive(:get).with(:ai_provider).and_return("openai")
    allow(settings).to receive(:get).with(:ai_model).and_return("gpt-3.5-turbo")
  end

  describe "#generate_commit_message" do
    context "with OpenAI provider", :vcr do
      it "generates a conventional commit message" do
        message = service.generate_commit_message(diff, style: :conventional)
        expect(message).to be_a(String)
        expect(message).not_to be_empty
      end

      it "generates a simple commit message" do
        message = service.generate_commit_message(diff, style: :simple)
        expect(message).to be_a(String)
        expect(message).not_to be_empty
      end

      it "respects provided scope" do
        message = service.generate_commit_message(diff, style: :conventional, scope: "test")
        expect(message).to be_a(String)
        expect(message).not_to be_empty
      end
    end

    context "with invalid input" do
      it "raises error for empty diff" do
        expect do
          service.generate_commit_message("")
        end.to raise_error(GitAuto::Services::AIService::EmptyDiffError)
      end

      it "raises error for too large diff" do
        large_diff = "a" * (GitAuto::Services::AIService::MAX_DIFF_SIZE + 1)
        expect do
          service.generate_commit_message(large_diff)
        end.to raise_error(GitAuto::Services::AIService::DiffTooLargeError)
      end

      context "with missing API key" do
        before do
          allow(settings).to receive(:get).with(:openai_api_key).and_return(nil)
        end

        it "raises error for missing API key" do
          expect do
            service.generate_commit_message(diff)
          end.to raise_error(GitAuto::Services::AIService::APIKeyError)
        end
      end
    end
  end

  describe "retry behavior" do
    before do
      allow(service).to receive(:generate_openai_commit_message).and_raise(StandardError)
    end

    it "retries on failure up to MAX_RETRIES times" do
      expect do
        service.generate_commit_message(diff)
      end.to raise_error(StandardError)
      expect(service).to have_received(:generate_openai_commit_message).exactly(GitAuto::Services::AIService::MAX_RETRIES).times
    end
  end

  describe "error handling" do
    context "with missing API keys" do
      before do
        allow(settings).to receive(:get).with(:openai_api_key).and_return(nil)
      end

      it "raises an error when API key is missing" do
        expect { service.generate_conventional_commit(diff) }.to raise_error(GitAuto::Services::AIService::APIKeyError)
      end
    end

    context "with empty diff" do
      it "raises an error when diff is empty" do
        expect { service.generate_conventional_commit("") }.to raise_error(GitAuto::Services::AIService::EmptyDiffError)
      end
    end

    context "with rate limiting" do
      it "handles rate limiting gracefully", :vcr do
        3.times { service.generate_commit_message(diff) }
        expect { service.generate_commit_message(diff) }.to raise_error(GitAuto::Services::AIService::RateLimitError)
      end
    end
  end
end
