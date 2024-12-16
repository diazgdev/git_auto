# frozen_string_literal: true

RSpec.describe GitAuto do
  it "has a version number" do
    expect(GitAuto::VERSION).not_to be_nil
  end

  describe ".root" do
    it "returns the root directory path" do
      expect(described_class.root).to be_a(String)
      expect(File.directory?(described_class.root)).to be true
    end
  end

  describe ".install" do
    before do
      # Backup existing config directory if it exists
      @config_dir = GitAuto::Config::Settings::CONFIG_DIR
      FileUtils.mv(@config_dir, "#{@config_dir}.bak") if File.directory?(@config_dir)
    end

    after do
      # Clean up test config directory and restore backup
      FileUtils.rm_rf(@config_dir)
      FileUtils.mv("#{@config_dir}.bak", @config_dir) if File.exist?("#{@config_dir}.bak")
    end

    it "creates the config directory" do
      described_class.install
      expect(File.directory?(@config_dir)).to be true
    end
  end

  describe ".uninstall" do
    before do
      described_class.install # Ensure config directory exists
    end

    it "removes the config directory" do
      described_class.uninstall
      expect(File.directory?(GitAuto::Config::Settings::CONFIG_DIR)).to be false
    end
  end
end
