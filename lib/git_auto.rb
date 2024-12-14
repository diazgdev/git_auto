# frozen_string_literal: true

require "git_auto/version"
require "git_auto/errors"
require "git_auto/config/settings"
require "git_auto/config/credential_store"
require "git_auto/services/ai_service"
require "git_auto/services/git_service"
require "git_auto/services/history_service"
require "git_auto/commands/setup_command"
require "git_auto/commands/config_command"
require "git_auto/commands/commit_message_command"
require "git_auto/cli"
require "thor"
require "tty-prompt"
require "tty-spinner"
require "colorize"
require "http"
require "clipboard"
require "fileutils"
require_relative "git_auto/formatters/diff_formatter"
require_relative "git_auto/formatters/diff_summarizer"
require_relative "git_auto/formatters/message_formatter"

module GitAuto
  class Error < StandardError; end

  class << self
    def root
      File.expand_path("..", __dir__)
    end

    def install
      # Create config directory if it doesn't exist
      FileUtils.mkdir_p(Config::Settings::CONFIG_DIR)
    end

    def uninstall
      # Remove config directory and all its contents if it exists
      FileUtils.rm_rf(Config::Settings::CONFIG_DIR)
    end
  end
end

Gem.post_install do |installer|
  GitAuto.install if installer.spec.name == "git_auto"
end

Gem.pre_uninstall do |uninstaller|
  GitAuto.uninstall if uninstaller.spec.name == "git_auto"
end
