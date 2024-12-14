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

      CONVENTIONAL_COMMIT_PATTERN = %r{
        ^(?<type>#{TYPES.keys.join("|")})           # Commit type
        (\((?<scope>[a-z0-9/_-]+)\))?               # Optional scope in parentheses
        :\s                                         # Colon and space separator
        (?<description>.+)                          # Commit description
      }x

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

        # Validate header format for conventional commits
        valid_types = TYPES.keys.join('|')
        pattern = %r{^(?:#{valid_types})\([a-z0-9/_-]+\)?: .+$}

        unless pattern.match?(header)
          errors << "Header must follow conventional commit format: <type>(<scope>): <description>"
        end

        # Suggest using lowercase for consistency
        warnings << "Consider using lowercase for the commit message" if header =~ /[A-Z]/

        { errors: errors, warnings: warnings }
      end
    end
  end
end
