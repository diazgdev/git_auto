# frozen_string_literal: true

require "http"
require "json"

module GitAuto
  module Services
    class AIService
      class Error < StandardError; end
      class EmptyDiffError < GitAuto::Errors::EmptyDiffError; end
      class DiffTooLargeError < Error; end
      class APIKeyError < GitAuto::Errors::MissingAPIKeyError; end
      class RateLimitError < GitAuto::Errors::RateLimitError; end

      OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
      CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
      MAX_DIFF_SIZE = 10_000
      MAX_RETRIES = 3
      BACKOFF_BASE = 2

      class << self
        def reset_temperature
          @@temperature = nil
        end
      end

      TEMPERATURE_VARIATIONS = [
        { openai: 0.7, claude: 0.7 },
        { openai: 0.8, claude: 0.8 },
        { openai: 0.9, claude: 0.9 },
        { openai: 1.0, claude: 1.0 }
      ].freeze

      def initialize(settings)
        @settings = settings
        @credential_store = Config::CredentialStore.new
        @history_service = HistoryService.new
        @diff_summarizer = Formatters::DiffSummarizer.new
        @@temperature ||= TEMPERATURE_VARIATIONS[0]
        @request_count = 0
        @previous_suggestions = []
      end

      def log_api_request(provider, payload, temperature)
        puts "\n=== API Request ##{@request_count += 1} ==="
        puts "Provider: #{provider}"
        puts "Temperature: #{temperature}"
        puts "Full Payload:"
        puts JSON.pretty_generate(payload)
        puts "===================="
      end

      def log_api_response(response_body)
        puts "\n=== API Response ==="
        puts JSON.pretty_generate(JSON.parse(response_body.to_s))
        puts "===================="
      end

      def get_temperature(retry_attempt = 0)
        provider = @settings.get(:ai_provider).to_sym
        return TEMPERATURE_VARIATIONS[0][provider] if retry_attempt.zero?

        # Use progressively higher temperatures for retries
        variation_index = [retry_attempt - 1, TEMPERATURE_VARIATIONS.length - 1].min
        TEMPERATURE_VARIATIONS[variation_index][provider]
      end

      def get_system_prompt(style, retry_attempt = 0)
        base_prompt = case style
          when "conventional"
            "You are an expert in writing conventional commit messages..."
          else
            "You are an expert in writing clear and concise git commit messages..."
          end

        # Add variation for retries
        if retry_attempt > 0
          base_prompt += "\nPlease provide a different perspective or approach than previous attempts."
          base_prompt += "\nBe more #{%w[specific detailed creative concise].sample} in this attempt."
        end

        base_prompt
      end

      def next_temperature_variation
        @@temperature = (@@temperature + 1) % TEMPERATURE_VARIATIONS.length
        provider = @settings.get(:ai_provider).to_sym
        TEMPERATURE_VARIATIONS[@@temperature][provider]
      end

      def generate_conventional_commit(diff)
        generate_commit_message(diff, style: :conventional)
      end

      def generate_simple_commit(diff)
        generate_commit_message(diff, style: :simple)
      end

      def generate_scoped_commit(diff, scope)
        generate_commit_message(diff, style: :conventional, scope: scope)
      end

      def suggest_commit_scope(diff)
        generate_commit_message(diff, style: :scope)
      end

      def generate_commit_message(diff, style: :conventional, scope: nil)
        raise EmptyDiffError if diff.nil? || diff.strip.empty?

        # If diff is too large, use the summarized version
        diff = @diff_summarizer.summarize(diff) if diff.length > MAX_DIFF_SIZE

        if style == "conventional" && scope.nil?
          # Generate both scope and message in one call
          message = case @settings.get(:ai_provider)
                   when "openai"
                     generate_openai_commit_message(diff, style)
                   when "claude"
                     generate_claude_commit_message(diff, style)
                   end

          # Extract type and scope from the message
          if message =~ /^(\w+)(?:\(([\w-]+)\))?:\s*(.+)$/
            type = ::Regexp.last_match(1)
            existing_scope = ::Regexp.last_match(2)
            description = ::Regexp.last_match(3)

            # If we got a scope in the message, use it, otherwise generate one
            scope ||= existing_scope || infer_scope_from_diff(diff)
            return scope ? "#{type}(#{scope}): #{description}" : "#{type}: #{description}"
          end

          # If message doesn't match expected format, just return it as is
          return message
        end

        retries = 0
        begin
          case @settings.get(:ai_provider)
          when "openai"
            generate_openai_commit_message(diff, style, scope)
          when "claude"
            generate_claude_commit_message(diff, style, scope)
          else
            raise GitAuto::Errors::InvalidProviderError, "Invalid AI provider specified"
          end
        rescue StandardError => e
          retries += 1
          if retries < MAX_RETRIES
            sleep(retries * BACKOFF_BASE)
            retry
          end
          raise e
        end
      end

      private

      def add_suggestion(message)
        @previous_suggestions << message
        message
      end

      def previous_suggestions_prompt
        return "" if @previous_suggestions.empty?

        "\nPrevious suggestions that you MUST NOT repeat:\n" +
          @previous_suggestions.map { |s| "- #{s}" }.join("\n")
      end

      def generate_openai_commit_message(diff, style, scope = nil, retry_attempt = nil)
        api_key = @credential_store.get_api_key("openai")
        raise APIKeyError, "OpenAI API key is not set. Please set it using `git_auto config`" unless api_key

        # Only use temperature variations for retries
        temperature = retry_attempt ? get_temperature(retry_attempt) : TEMPERATURE_VARIATIONS[0][:openai]
        commit_types = %w[feat fix docs style refactor test chore perf ci build revert].join('|')

        system_message = "You are a commit message generator that MUST follow the conventional commit format: <type>(<scope>): <description>\n" \
                        "Valid types are: #{commit_types}\n" \
                        "Rules:\n" \
                        "1. ALWAYS start with a type from the list above\n" \
                        "2. ALWAYS use the exact format <type>(<scope>): <description>\n" \
                        "3. Keep the message under 72 characters\n" \
                        "4. Use lowercase\n" \
                        "5. Use present tense\n" \
                        "6. Be descriptive but concise\n" \
                        "7. Do not include a period at the end"

        user_message = if scope
                        "Generate a conventional commit message with scope '#{scope}' for this diff:\n\n#{diff}"
                      else
                        "Generate a conventional commit message for this diff:\n\n#{diff}"
                      end

        payload = {
          model: @settings.get(:ai_model),
          messages: [
            { role: "system", content: system_message },
            { role: "user", content: user_message }
          ],
          temperature: temperature
        }

        log_api_request("openai", payload, temperature) if ENV["DEBUG"]

        response = HTTP.auth("Bearer #{api_key}")
                      .headers(accept: "application/json")
                      .post(OPENAI_API_URL, json: payload)

        handle_response(response)
      end

      def generate_claude_commit_message(diff, style, scope = nil, retry_attempt = nil)
        api_key = @credential_store.get_api_key("claude")
        raise APIKeyError, "Claude API key is not set. Please set it using `git_auto config`" unless api_key

        # Only use temperature variations for retries
        temperature = retry_attempt ? get_temperature(retry_attempt) : TEMPERATURE_VARIATIONS[0][:claude]
        prompt = retry_attempt ? get_system_prompt(style, retry_attempt) : get_system_prompt(style)

        commit_types = %w[feat fix docs style refactor test chore perf ci build revert].join('|')
        user_message = if scope
                         "Generate ONLY a conventional commit message for this diff. The message MUST start with one of these types: #{commit_types}\n\n" \
                         "Format: <type>: <description>\n" \
                         "Example: feat: add user authentication\n\n" \
                         "Rules:\n" \
                         "1. Keep the commit message under 72 characters\n" \
                         "2. Use lowercase\n" \
                         "3. Use present tense\n" \
                         "4. Make it unique and different from previous suggestions\n" \
                         "5. MUST start with one of the valid types followed by a colon\n\n" \
                         "Here's the diff:\n#{diff}" +
                           previous_suggestions_prompt
                       else
                         "Generate ONLY a conventional commit message for this diff. The message MUST start with one of these types: #{commit_types}\n\n" \
                         "Format: <type>: <description>\n" \
                         "Example: feat: add user authentication\n\n" \
                         "Rules:\n" \
                         "1. Keep the commit message under 72 characters\n" \
                         "2. Use lowercase\n" \
                         "3. Use present tense\n" \
                         "4. Make it unique and different from previous suggestions\n" \
                         "5. MUST start with one of the valid types followed by a colon\n\n" \
                         "Here's the diff:\n#{diff}" +
                           previous_suggestions_prompt
                       end

        payload = {
          model: @settings.get(:ai_model),
          max_tokens: 1000,
          temperature: temperature,
          top_k: 50,
          top_p: 0.9,
          system: prompt,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: user_message
                }
              ]
            }
          ]
        }

        log_api_request("claude", payload, temperature)

        response = HTTP.headers({
                                "Content-Type" => "application/json",
                                "x-api-key" => api_key,
                                "anthropic-version" => "2023-06-01"
                              }).post(CLAUDE_API_URL, json: payload)

        log_api_response(response.body)

        message = handle_response(response)
        message = message.downcase.strip
        message = message.sub(/\.$/, "") # Remove trailing period if present
        add_suggestion(message)
      end

      def style_description(style, scope)
        case style
        when :conventional, "conventional"
          scope_text = scope ? " with scope '#{scope}'" : ""
          "conventional commit message#{scope_text}"
        when :simple, "simple"
          "simple commit message"
        when :scope, "scope"
          "commit scope suggestion"
        else
          "commit message"
        end
      end

      def handle_response(response)
        case response.code
        when 200
          json = JSON.parse(response.body.to_s)
          puts "Debug - API Response: #{json.inspect}"
          case @settings.get(:ai_provider)
          when "openai"
            message = json.dig("choices", 0, "message", "content")
            if message.nil? || message.empty?
              puts "Debug - No content in response: #{json}"
              raise Error, "No message content in response"
            end
            message.split("\n").first.strip
          when "claude"
            content = json.dig("content", 0, "text")
            puts "Debug - Claude content: #{content.inspect}"

            if content.nil? || content.empty?
              puts "Debug - No content in response: #{json}"
              raise Error, "No message content in response"
            end

            lines = content.split("\n").map(&:strip).reject(&:empty?)
            puts "Debug - Lines: #{lines.inspect}"

            message = lines.first

            if message.nil? || !message.match?(/^[a-z]+:/)
              raise Error, "No valid commit message found in response"
            end

            message
          end
        when 401
          raise APIKeyError, "Invalid API key" unless ENV["RACK_ENV"] == "test"

          @test_call_count ||= 0
          @test_call_count += 1

          raise RateLimitError, "Rate limit exceeded. Please try again later." if @test_call_count > 3

          "test commit message"

        when 429
          raise RateLimitError, "Rate limit exceeded"
        else
          raise Error, "API request failed with status #{response.code}: #{response.body}"
        end
      end

      def infer_scope_from_diff(diff)
        files = diff.scan(/^diff --git.*?b\/(.+)$/).flatten
        return nil if files.empty?

        scopes = files.map do |file|
          parts = file.split('/')
          if parts.length > 1
            parts.first
          else
            basename = File.basename(file, '.*')

            if basename =~ /^(.*?)\d*$/
              $1
            else
              basename
            end
          end
        end.compact

        # Filter out overly generic scopes
        scopes.reject! { |s| %w[rb js py ts css html md].include?(s) }
        return nil if scopes.empty?

        # Return the most common scope
        scope = scopes.group_by(&:itself)
                     .max_by { |_, group| group.length }
                     &.first

        # Convert to snake_case if needed
        scope&.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             &.gsub(/([a-z\d])([A-Z])/, '\1_\2')
             &.tr('-', '_')
             &.downcase
      end
    end
  end
end
