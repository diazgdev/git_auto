# frozen_string_literal: true

require "yaml"
require "fileutils"

module GitAuto
  module Config
    class Settings
      class Error < StandardError; end

      CONFIG_DIR = File.expand_path("~/.git_auto")
      CONFIG_FILE = File.join(CONFIG_DIR, "config.yml")

      SUPPORTED_PROVIDERS = {
        "claude" => {
          name: "Anthropic (Claude 3.5 Sonnet, Claude 3.5 Haiku)",
          models: {
            "Claude 3.5 Sonnet" => "claude-3-5-sonnet-latest",
            "Claude 3.5 Haiku" => "claude-3-5-haiku-latest"
          }
        },
        "openai" => {
          name: "OpenAI (GPT-4o, GPT-4o mini)",
          models: {
            "GPT-4o" => "gpt-4o",
            "GPT-4o mini" => "gpt-4o-mini"
          }
        }
      }.freeze

      DEFAULT_SETTINGS = {
        commit_style: "conventional",
        ai_provider: "openai",
        ai_model: "gpt-4o",
        show_diff: true,
        save_history: true,
        max_retries: 3
      }.freeze

      def initialize
        ensure_config_dir
        @settings = load_settings
      end

      def save(options = {})
        validate_settings!(options)
        @settings = @settings.merge(options)
        File.write(CONFIG_FILE, YAML.dump(@settings))
      end

      def get(key)
        @settings[key.to_sym]
      end

      def all
        @settings
      end

      def provider_info
        SUPPORTED_PROVIDERS[get(:ai_provider)]
      end

      def available_models
        provider_info[:models]
      end

      private

      def ensure_config_dir
        FileUtils.mkdir_p(CONFIG_DIR)
      end

      def load_settings
        if File.exist?(CONFIG_FILE)
          YAML.load_file(CONFIG_FILE).transform_keys(&:to_sym)
        else
          DEFAULT_SETTINGS.dup
        end
      end

      def validate_settings!(options)
        if options[:ai_provider] && !SUPPORTED_PROVIDERS.key?(options[:ai_provider])
          raise Error, "Unsupported AI provider: #{options[:ai_provider]}"
        end

        return unless options[:ai_model]

        provider = options[:ai_provider] || @settings[:ai_provider]
        valid_models = SUPPORTED_PROVIDERS[provider][:models].values
        return if valid_models.include?(options[:ai_model])

        raise Error, "Unsupported AI model: #{options[:ai_model]}"
      end
    end
  end
end
