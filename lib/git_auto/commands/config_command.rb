# frozen_string_literal: true

require "tty-prompt"
require "colorize"

module GitAuto
  module Commands
    class ConfigCommand
      def initialize
        @prompt = TTY::Prompt.new
        @credential_store = Config::CredentialStore.new
        @settings = Config::Settings.new
      end

      def execute(args = [])
        if args.empty?
          interactive_config
        else
          handle_config_args(args)
        end
      end

      private

      def handle_config_args(args)
        case args[0]
        when "get"
          get_setting(args[1])
        when "set"
          set_setting(args[1], args[2])
        else
          puts "❌ Unknown command: #{args[0]}".red
          puts "Usage: git_auto config [get|set] <key> [value]"
          exit 1
        end
      end

      def get_setting(key)
        if key.nil?
          puts "❌ Missing key".red
          puts "Usage: git_auto config get <key>"
          exit 1
        end

        value = @settings.get(key.to_sym)
        if value.nil?
          puts "❌ Setting '#{key}' not found".red
          exit 1
        end

        puts value
      end

      def set_setting(key, value)
        if key.nil? || value.nil?
          puts "❌ Missing key or value".red
          puts "Usage: git_auto config set <key> <value>"
          exit 1
        end

        case key.to_s
        when "openai_api_key"
          @credential_store.store_api_key(value, "openai")
          puts "✓ OpenAI API key updated".green
        when "claude_api_key"
          @credential_store.store_api_key(value, "claude")
          puts "✓ Claude API key updated".green
        when "gemini_api_key"
          @credential_store.store_api_key(value, "gemini")
          puts "✓ Gemini API key updated".green
        else
          @settings.set(key.to_sym, value)
          puts "✓ Setting '#{key}' updated to '#{value}'".green
        end
      end

      def interactive_config
        puts "\n⚙️  GitAuto Configuration".blue

        loop do
          choice = main_menu
          break if choice == "exit"

          case choice
          when "show"
            display_configuration
          when "provider"
            configure_ai_provider
          when "model"
            configure_ai_model
          when "api_key"
            configure_api_key
          when "style"
            configure_commit_style
          when "preferences"
            configure_preferences
          when "history"
            configure_history_settings
          end
        end
      end

      def main_menu
        @prompt.select("Choose an option:", {
                         "📊 Show current configuration" => "show",
                         "🤖 Configure AI provider" => "provider",
                         "🔧 Configure AI model" => "model",
                         "🔑 Configure API key" => "api_key",
                         "💫 Configure commit style" => "style",
                         "⚙️  Configure preferences" => "preferences",
                         "📜 Configure history settings" => "history",
                         "❌ Exit" => "exit"
                       })
      end

      def display_configuration
        puts "\nCurrent Configuration:".blue
        puts "AI Provider: #{@settings.get(:ai_provider)}"
        puts "AI Model: #{@settings.get(:ai_model)}"
        puts "Commit Style: #{@settings.get(:commit_style)}"
        puts "Show Diff: #{@settings.get(:show_diff)}"
        puts "Save History: #{@settings.get(:save_history)}"
        puts "\nPress any key to continue..."
        @prompt.keypress
      end

      def configure_ai_provider
        # Use the supported providers from settings
        provider_choices = Config::Settings::SUPPORTED_PROVIDERS.map do |key, info|
          { name: info[:name], value: key }
        end

        provider = @prompt.select("Choose AI provider:", provider_choices)

        @settings.save(ai_provider: provider)
        puts "✓ AI provider updated to #{provider}".green

        # Check if API key exists for the new provider
        unless @credential_store.api_key_exists?(provider)
          puts "\nNo API key found for #{provider.upcase}. Let's set it up.".blue
          configure_api_key
        end

        # Auto-configure model after provider change
        configure_ai_model
      end

      def configure_ai_model
        models = Config::Settings::SUPPORTED_PROVIDERS[@settings.get(:ai_provider)][:models]
        model_choices = models.map { |name, value| { name: name, value: value } }

        model = @prompt.select("Choose AI model:", model_choices)
        @settings.save(ai_model: model)
        puts "✓ AI model updated to #{model}".green
      end

      def configure_api_key
        provider = @settings.get(:ai_provider)
        puts "\nConfiguring API key for #{provider.upcase}".blue

        key = @prompt.mask("Enter your API key:")
        @credential_store.store_api_key(key, provider)
        puts "✓ API key updated".green
      end

      def configure_commit_style
        style = @prompt.select("Choose commit message style:", {
                                 "Minimal (type: description)" => "minimal",
                                 "Conventional (type(scope): description)" => "conventional",
                                 "Simple (description only)" => "simple"
                               })

        @settings.save(commit_style: style)
        puts "✓ Commit style updated to #{style}".green
      end

      def configure_preferences
        show_diff = @prompt.yes?("Show diff before committing?")
        @settings.save(show_diff: show_diff)
        puts "✓ Show diff preference updated".green
      end

      def configure_history_settings
        save_history = @prompt.yes?("Save commit history for analysis?")
        @settings.save(save_history: save_history)
        puts "✓ History settings updated".green
      end
    end
  end
end
