# frozen_string_literal: true

require "thor"
require "tty-prompt"
require "colorize"

module GitAuto
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Add version information
    map ["--version", "-v"] => :version
    desc "--version, -v", "Print version"
    def version
      puts "git_auto version #{GitAuto::VERSION}"
    end

    desc "setup", "Configure GitAuto settings and API keys"
    long_desc <<-LONGDESC
      Interactive setup wizard for GitAuto.

      This will guide you through:
      * Selecting an AI provider (Claude or OpenAI)
      * Configuring your API key
      * Setting commit message preferences
      * Configuring other options
    LONGDESC
    def setup
      Commands::SetupCommand.new.execute
    end

    desc "config [get|set] [key] [value]", "View or update configuration"
    long_desc <<-LONGDESC
      Manage GitAuto configuration.

      Examples:
        git_auto config                    # Interactive configuration
        git_auto config get               # Show all settings
        git_auto config get ai_provider   # Show specific setting
        git_auto config set ai_model gpt-4 # Update specific setting
    LONGDESC
    def config(*args)
      Commands::ConfigCommand.new.execute(args)
    end

    desc "commit", "Generate AI-powered commit message"
    method_option :style, type: :string, desc: "Commit message style (conventional, simple, detailed)"
    method_option :scope, type: :string, desc: "Commit scope for conventional style"
    method_option :preview, type: :boolean, desc: "Show diff preview before committing"
    long_desc <<-LONGDESC
      Generate an AI-powered commit message for your staged changes.

      Examples:
        git_auto commit                    # Use default style
        git_auto commit --style simple     # Use simple style
        git_auto commit --style conventional --scope api  # Specify scope
    LONGDESC
    def commit
      Commands::CommitMessageCommand.new(options).execute
    end

    desc "analyze", "Analyze commit history patterns"
    method_option :limit, type: :numeric, default: 10, desc: "Number of commits to analyze"
    method_option :save, type: :boolean, desc: "Save patterns for future commits"
    long_desc <<-LONGDESC
      Analyze your repository's commit history to learn patterns and improve future commit messages.

      Examples:
        git_auto analyze              # Analyze last 10 commits
        git_auto analyze --limit 50   # Analyze last 50 commits
        git_auto analyze --save       # Save patterns for future use
    LONGDESC
    def analyze
      Commands::HistoryAnalysisCommand.new(options).execute
    end
  end
end
