# frozen_string_literal: true

require "tty-prompt"
require "tty-spinner"
require "colorize"
require "clipboard"
require_relative "../formatters/diff_formatter"
require_relative "../formatters/message_formatter"
require_relative "../validators/commit_message_validator"

module GitAuto
  module Commands
    class CommitMessageCommand
      def initialize(options = {})
        @options = options.dup
        @prompt = TTY::Prompt.new
        @spinner = TTY::Spinner.new("[:spinner] :message...")
        @settings = Config::Settings.new
        @git_service = Services::GitService.new
        @ai_service = Services::AIService.new(@settings)
        @history_service = Services::HistoryService.new
        @validator = Validators::CommitMessageValidator.new(get_commit_style)
        @retry_count = 0
      end

      def execute
        # Get repository status
        status = @git_service.repository_status
        validate_repository(status)

        # Get staged files
        staged_files = @git_service.get_staged_files

        # Get and validate changes
        diff = @git_service.get_staged_diff(staged_files)
        validate_changes(diff)

        # Show diff preview if requested
        show_diff_preview(diff) if show_preview?

        # Generate commit message
        message = generate_commit_message(diff)

        # Handle the generated message
        handle_message(message, diff)
      rescue StandardError => e
        puts "\n❌ Error: #{e.message}".red
        exit 1
      end

      private

      # Repository and Change Validation Methods
      def validate_repository(status)
        return if status[:has_staged_changes]

        puts "ℹ️  Status:".blue
        puts "  No changes staged for commit"
        puts "\n❌ No changes staged for commit. Use 'git add' to stage changes.".red
        exit 1
      end

      def validate_changes(diff)
        return unless diff.empty?

        puts "❌ No staged changes found. Use 'git add' first.".red
        exit 1
      end

      # Preview Methods
      def show_preview?
        @options[:preview] || @settings.get(:show_diff)
      end

      def show_diff_preview(diff)
        puts "\n📄 Changes to be committed:".blue
        puts Formatters::DiffFormatter.new.format(diff)

        return if @prompt.yes?("Continue with these changes?")

        puts "Operation cancelled.".yellow
        exit 0
      end

      # Message Generation Methods
      def generate_commit_message(diff, options = @options)
        style = get_commit_style
        scope = options[:scope]

        if style == "conventional" && scope.nil?
          # Show recent scopes for reference
          patterns = @history_service.analyze_patterns(20)
          if patterns && patterns[:scopes]&.any?
            puts "\n📊 Recently used scopes:".blue
            patterns[:scopes].each do |scope, count|
              puts "  #{scope}: #{count} times"
            end
          end

          generate_message_with_style(diff, style, nil)

        else
          generate_message_with_style(diff, style, scope)
        end
      end

      def get_commit_style
        @options[:style] || @settings.get(:commit_style)
      end

      def generate_message_with_style(diff, style, scope)
        @spinner.update(message: "Generating commit message...")
        @spinner.auto_spin
        message = @ai_service.generate_commit_message(diff, style: style, scope: scope)
        @spinner.success("✓ Message generated".green)
        message
      end

      # Message Validation Methods
      def validate_message(message)
        result = @validator.validate(message)

        if result[:errors].any?
          puts "\n❌ Validation errors:".red
          result[:errors].each { |error| puts @validator.format_error(error) }
        end

        if result[:warnings].any?
          puts "\n⚠️  Suggestions:".yellow
          result[:warnings].each { |warning| puts @validator.format_warning(warning) }
        end

        puts "\nPlease edit the message to fix these errors." if result[:errors].any?
        result
      end

      # Message Handling Methods
      def handle_message(message, diff)
        formatted = Formatters::MessageFormatter.new.format(message)
        validation = validate_message(message)
        display_message_and_validation(formatted, validation)

        loop do
          choice = prompt_user_action
          break if handle_user_choice(choice, message, diff, validation)
        end
      end

      def display_message_and_validation(formatted_message, validation)
        puts "\n📝 Generated commit message (#{@settings.get(:ai_provider)}/#{@settings.get(:ai_model)}):".blue
        puts formatted_message

        return unless validation[:errors].any? || validation[:warnings].any?

        if validation[:errors].any?
          puts "\n❌ Validation errors:".red
          validation[:errors].each { |error| puts @validator.format_error(error) }
        end

        if validation[:warnings].any?
          puts "\n⚠️  Suggestions:".yellow
          validation[:warnings].each { |warning| puts @validator.format_warning(warning) }
        end

        puts "\nPlease edit the message to fix these errors." if validation[:errors].any?
      end

      def prompt_user_action
        @prompt.select("Choose an action:", {
                         "✅ Accept and commit" => :accept,
                         "✏️  Edit message" => :edit,
                         "📋 Copy to clipboard" => :copy,
                         "👀 Show diff" => :diff,
                         "📊 Show patterns" => :patterns,
                         "🔄 Generate new message" => :retry,
                         "❌ Cancel" => :cancel
                       })
      end

      # User Action Handling Methods
      def handle_user_choice(choice, message, diff, validation)
        case choice
        when :accept
          handle_accept_action(message, diff, validation)
        when :edit
          handle_edit_action(message)
          false
        when :copy
          handle_copy_action(message)
          false
        when :diff
          show_diff_preview(diff)
          false
        when :patterns
          show_commit_patterns
          false
        when :retry
          handle_retry_action(diff)
          false
        when :cancel
          cancel_operation
        end
      end

      def handle_accept_action(message, diff, validation)
        if validation[:errors].any?
          puts "\n❌ Cannot commit: Please fix validation errors first.".red
          new_message = edit_message(message)
          handle_message(new_message, diff)
          return true
        end
        accept_message(message, diff)
        true
      end

      def handle_edit_action(message)
        new_message = edit_message(message)
        puts "\n📝 Updated message:".blue
        puts Formatters::MessageFormatter.new.format(new_message)
      end

      def handle_copy_action(message)
        Clipboard.copy(message)
        puts "✓ Copied to clipboard".green
      end

      def handle_retry_action(diff)
        @retry_count += 1

        # Create a new options hash for this retry
        retry_options = @options.transform_keys(&:to_s)
        retry_options["creativity"] = [(retry_options["creativity"].to_f + 0.1), 1.0].min if retry_options["creativity"]
        retry_options["retry_attempt"] = @retry_count

        new_message = generate_commit_message(diff, retry_options)
        puts "\n📝 New message (Attempt #{@retry_count}):".blue
        formatted = Formatters::MessageFormatter.new.format(new_message)
        puts formatted

        # Validate the message
        validation = validate_message(new_message)
        display_message_and_validation(formatted, validation) if validation[:errors].any? || validation[:warnings].any?

        handle_message(new_message, diff)
      end

      # Pattern Analysis Methods
      def show_commit_patterns
        puts "\n📊 Analyzing commit patterns...".blue
        patterns = @history_service.analyze_patterns
        return unless patterns

        display_pattern_section(patterns[:styles], "Commit Styles")
        display_pattern_section(patterns[:types], "Common Types")
        display_pattern_section(patterns[:scopes], "Frequent Scopes", count_format: true)
        display_pattern_section(patterns[:common_phrases], "Common Phrases", count_format: true)

        wait_for_user_input
      end

      def display_pattern_section(data, title, count_format: false)
        return unless data&.any?

        puts "\n#{title}:".cyan
        display_pattern_items(data, count_format)
      end

      def display_pattern_items(items, count_format)
        items.each do |key, value|
          formatted_value = format_pattern_value(value, count_format)
          puts "  #{key}: #{formatted_value}"
        end
      end

      def format_pattern_value(value, count_format)
        if count_format
          "#{value} times"
        else
          "#{value}%"
        end
      end

      def wait_for_user_input
        puts "\nPress any key to continue..."
        @prompt.keypress
      end

      # Utility Methods
      def edit_message(message)
        puts "\nEdit your commit message:"
        puts "Enter your commit message (press Ctrl+D or Ctrl+Z to finish)".light_black
        editor_input = $stdin.gets
        editor_input&.strip || message
      end

      def accept_message(message, diff)
        @spinner.update(message: "Creating commit...")
        @spinner.auto_spin
        # Ensure we only use the first line
        message = message.split("\n").first.strip
        @git_service.commit(message)
        @spinner.success("✓ Commit created successfully!".green)

        # Save to history if enabled
        save_to_history(message, diff)
      end

      def save_to_history(message, diff)
        return unless @settings.get(:save_history)

        metadata = {
          files: @git_service.get_staged_files,
          diff_size: diff.length,
          style: @options[:style] || @settings.get(:commit_style)
        }

        @history_service.save_commit(message, metadata)
      end

      def cancel_operation
        puts "Operation cancelled.".yellow
        exit 0
      end
    end
  end
end
