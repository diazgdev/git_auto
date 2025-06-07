# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitAuto::Services::AIService do
  let(:settings) { instance_double(GitAuto::Config::Settings) }
  let(:credential_store) { instance_double(GitAuto::Config::CredentialStore) }
  let(:service) { described_class.new(settings) }
  let(:diff) { "diff --git a/file.rb b/file.rb\n+puts 'Hello World'" }

  before do
    allow(GitAuto::Config::CredentialStore).to receive(:new).and_return(credential_store)
    allow(GitAuto::Services::HistoryService).to receive(:new).and_return(
      instance_double(GitAuto::Services::HistoryService)
    )
    allow(settings).to receive(:get).with(:ai_provider).and_return("gemini")
    allow(settings).to receive(:get).with(:ai_model).and_return("gemini-2.5-flash")
    allow(settings).to receive(:get).with(:commit_style).and_return("conventional")
    allow(settings).to receive(:set)
  end

  describe "Gemini integration" do
    context "with valid API key" do
      before do
        allow(credential_store).to receive(:get_api_key).with("gemini").and_return("test-api-key")
      end

      it "generates commit message using Gemini API" do
        stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent})
          .to_return(
            status: 200,
            body: {
              candidates: [
                {
                  content: {
                    parts: [
                      { text: "feat: add hello world output" }
                    ]
                  }
                }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        message = service.generate_commit_message(diff, style: :conventional)
        expect(message).to eq("feat: add hello world output")
      end

      it "handles Gemini API errors gracefully" do
        stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent})
          .to_return(status: 403, body: { error: { message: "Invalid API key" } }.to_json)

        expect { service.generate_commit_message(diff) }
          .to raise_error(GitAuto::Services::AIService::APIKeyError, /Invalid Gemini API key/)
      end

      it "handles rate limiting" do
        stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent})
          .to_return(status: 429, body: { error: { message: "Rate limit exceeded" } }.to_json)

        expect { service.generate_commit_message(diff) }
          .to raise_error(GitAuto::Services::AIService::RateLimitError, /Gemini API rate limit exceeded/)
      end
    end

    context "with missing API key" do
      before do
        allow(credential_store).to receive(:get_api_key).with("gemini").and_return(nil)
      end

      it "raises API key error" do
        expect { service.generate_commit_message(diff) }
          .to raise_error(GitAuto::Services::AIService::APIKeyError, /Gemini API key is not set/)
      end
    end
  end
end