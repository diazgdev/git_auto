# frozen_string_literal: true

module GitAuto
  module Validators
    class CommitMessageValidator
      HEADER_MAX_LENGTH = 72

      # Conventional commit types and their descriptions
      TYPES = {
        "feat" => "A new feature",
        "fix" => "A bug fix",
        "docs" => "Documentation only changes",
        "style" => "Changes that do not affect the meaning of the code",
        "refactor" => "A code change that neither fixes a bug nor adds a feature",
        "test" => "Adding missing tests or correcting existing tests",
        "chore" => "Changes to the build process or auxiliary tools",
        "perf" => "A code change that improves performance",
        "ci" => "Changes to CI configuration files and scripts",
        "build" => "Changes that affect the build system or external dependencies",
        "revert" => "Reverts a previous commit"
      }.freeze

      MINIMAL_COMMIT_PATTERN = /
        ^(?<type>#{TYPES.keys.join("|")})           # Commit type
        :\s                                         # Colon and space separator
        (?<description>.+)                          # Commit description
      /x

      CONVENTIONAL_COMMIT_PATTERN = %r{
        ^(?<type>#{TYPES.keys.join("|")})           # Commit type
        (\((?<scope>[a-z0-9/_\.-]+)\))?               # Optional scope in parentheses
        :\s                                         # Colon and space separator
        (?<description>.+)                          # Commit description
      }x

      def initialize(style = "conventional")
        @style = style.to_s
      end

      def validate(message)
        errors = []
        warnings = []

        # Skip validation if message is empty
        return { errors: ["Commit message cannot be empty"], warnings: [] } if message.nil? || message.strip.empty?

        header_result = validate_header(message)
        errors.concat(header_result[:errors])
        warnings.concat(header_result[:warnings])

        { errors: errors, warnings: warnings }
      end

      def valid?(message)
        result = validate(message)
        result[:errors].empty?
      end

      def format_error(error)
        "❌ #{error}".red
      end

      def format_warning(warning)
        "⚠️  #{warning}".yellow
      end

      private

      def validate_header(message)
        errors = []
        warnings = []

        lines = message.split("\n")
        header = lines.first

        # Validate header presence and length
        if header.nil? || header.strip.empty?
          errors << "Header (first line) cannot be empty"
          return { errors: errors, warnings: warnings }
        end

        errors << "Header exceeds #{HEADER_MAX_LENGTH} characters" if header.length > HEADER_MAX_LENGTH

        # Validate header format based on style
        case @style
        when "conventional"
          errors << "Header must follow conventional format: <type>(<scope>): <description>" unless CONVENTIONAL_COMMIT_PATTERN.match?(header)
        when "minimal"
          errors << "Header must follow minimal format: <type>: <description>" unless MINIMAL_COMMIT_PATTERN.match?(header)
        when "simple", "detailed"
          # No specific format required for simple and detailed styles
        else
          # For unknown styles, suggest using conventional format
          warnings << "Unknown style '#{@style}', consider using conventional format: <type>(<scope>): <description>"
        end

        # Suggest using lowercase for consistency
        warnings << "Consider using lowercase for the commit message" if header =~ /[A-Z]/

        { errors: errors, warnings: warnings }
      end
    end
  end
end
