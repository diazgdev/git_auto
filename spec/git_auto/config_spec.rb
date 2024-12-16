# frozen_string_literal: true

RSpec.describe GitAuto::Config::Settings do
  let(:config) { described_class.new }
  let(:config_file) { described_class::CONFIG_FILE }

  before do
    # Backup existing config file if it exists
    FileUtils.mv(config_file, "#{config_file}.bak") if File.exist?(config_file)
  end

  after do
    # Clean up test config file and restore backup
    FileUtils.rm_f(config_file)
    FileUtils.mv("#{config_file}.bak", config_file) if File.exist?("#{config_file}.bak")
  end

  describe "#initialize" do
    it "sets default values" do
      expect(config.get(:ai_provider)).to eq("openai")
      expect(config.get(:ai_model)).to eq("gpt-4o")
      expect(config.get(:commit_style)).to eq("conventional")
    end
  end

  describe "#save" do
    it "saves settings to config file" do
      new_settings = {
        ai_provider: "claude",
        ai_model: "claude-3-5-sonnet-latest"
      }

      config.save(new_settings)

      # Create new instance to read from file
      new_config = described_class.new
      expect(new_config.get(:ai_provider)).to eq("claude")
      expect(new_config.get(:ai_model)).to eq("claude-3-5-sonnet-latest")
    end

    it "validates settings before saving" do
      expect do
        config.save(ai_provider: "invalid_provider")
      end.to raise_error(GitAuto::Config::Settings::Error)
    end

    it "handles invalid model for provider" do
      expect do
        config.save(ai_provider: "openai", ai_model: "invalid-model")
      end.to raise_error(GitAuto::Config::Settings::Error)
    end
  end

  describe "#get" do
    it "returns nil for unknown settings" do
      expect(config.get(:nonexistent_setting)).to be_nil
    end

    it "returns default value when setting is not configured" do
      expect(config.get(:commit_style)).to eq("conventional")
    end

    it "returns setting value when it exists" do
      config.save(custom_setting: "value")
      expect(config.get(:custom_setting)).to eq("value")
    end
  end
end
