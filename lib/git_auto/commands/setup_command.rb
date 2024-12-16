# frozen_string_literal: true

require "tty-prompt"
require "colorize"

module GitAuto
  module Commands
    class SetupCommand
      def initialize
        @prompt = TTY::Prompt.new
        @credential_store = Config::CredentialStore.new
        @settings = Config::Settings.new
      end

      def execute
        puts "\n🔧 Setting up GitAuto...".blue
        puts "This wizard will help you configure GitAuto with your preferred AI provider.\n"

        # Select AI provider
        configure_ai_provider

        # Configure preferences
        configure_preferences

        puts "\n✅ Setup completed successfully!".green
        display_configuration
      rescue StandardError => e
        puts "\n❌ Setup failed: #{e.message}".red
        exit 1
      end

      private

      def configure_ai_provider
        # Select provider
        provider_choices = Config::Settings::SUPPORTED_PROVIDERS.map do |key, info|
          { name: info[:name], value: key }
        end

        provider = @prompt.select(
          "Choose your AI provider:",
          provider_choices,
          help: "(Use ↑/↓ and Enter to select)"
        )

        # Select model for the chosen provider
        models = Config::Settings::SUPPORTED_PROVIDERS[provider][:models]
        model_choices = models.map { |name, value| { name: name, value: value } }

        model = @prompt.select(
          "Choose the AI model:",
          model_choices,
          help: "More capable models may be slower but produce better results"
        )

        # Get and validate API key
        provider_name = Config::Settings::SUPPORTED_PROVIDERS[provider][:name]
        puts "\nℹ️  The API key will be securely stored in your system's credential store"
        api_key = @prompt.mask("Enter your #{provider_name} API key:") do |q|
          q.required true
          q.validate(/\S+/, "API key cannot be empty")
        end

        # Save configuration
        @settings.save(
          ai_provider: provider,
          ai_model: model
        )
        @credential_store.store_api_key(api_key, provider)

        puts "✓ #{provider_name} configured successfully".green
      end

      def configure_preferences
        puts "\n🔧 Configuring preferences...".blue

        commit_style = select_commit_style
        show_diff = @prompt.yes?("Show diff preview before generating commit messages?", default: true)
        save_history = @prompt.yes?("Save commit history for pattern analysis?", default: true)

        settings = { commit_style: commit_style, show_diff: show_diff, save_history: save_history }

        @settings.save(settings)
      end

      def select_commit_style
        @prompt.select(
          "Select default commit message style:",
          [
            { name: "Minimal (type: subject)", value: "minimal" },
            { name: "Conventional (type(scope): description)", value: "conventional" },
            { name: "Simple (verb + description)", value: "simple" },
            { name: "Detailed (summary + bullet points)", value: "detailed" }
          ],
          help: "This can be changed later using git_auto config"
        )
      end

      def display_configuration
        config = @settings.all
        provider_info = Config::Settings::SUPPORTED_PROVIDERS[config[:ai_provider]]

        puts "\nCurrent Configuration:"
        puts "──────────────────────"
        puts "AI Provider: #{provider_info[:name]} (#{config[:ai_provider]})".cyan
        puts "Model: #{config[:ai_model]}".cyan
        puts "Commit Style: #{config[:commit_style]}".cyan
        puts "Show Diff: #{config[:show_diff]}".cyan
        puts "Save History: #{config[:save_history]}".cyan
        puts "\nYou can change these settings anytime using: git_auto config"
      end
    end
  end
end
