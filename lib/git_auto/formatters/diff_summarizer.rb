# frozen_string_literal: true

module GitAuto
  module Formatters
    class DiffSummarizer
      FileChange = Struct.new(:name, :additions, :deletions, :key_changes)

      def summarize(diff)
        return "No changes" if diff.empty?

        file_changes = parse_diff(diff)
        generate_summary(file_changes)
      end

      private

      def parse_diff(diff)
        changes = {}
        current_file = nil
        current_changes = nil

        diff.each_line do |line|
          case line
          when /^diff --git/
            changes[current_file] = current_changes if current_file
            current_file = extract_file_name(line)
            current_changes = FileChange.new(current_file, 0, 0, [])
          when /^\+(?!\+\+)/
            next if current_changes.nil?

            current_changes.additions += 1
            content = line[1..].strip
            current_changes.key_changes << "+#{content}" if key_change?(content)
          when /^-(?!--)/
            next if current_changes.nil?

            current_changes.deletions += 1
            content = line[1..].strip
            current_changes.key_changes << "-#{content}" if key_change?(content)
          end
        end

        # Add the last file's changes
        changes[current_file] = current_changes if current_file

        changes
      end

      def generate_summary(changes)
        return "No changes" if changes.empty?

        total_additions = 0
        total_deletions = 0
        summary = []

        summary << "[Summary: Changes across #{changes.size} files]"

        changes.each_value do |change|
          total_additions += change.additions
          total_deletions += change.deletions
        end

        summary << "Total: +#{total_additions} lines added, -#{total_deletions} lines removed"
        summary << "\nFiles modified:"

        changes.each_value do |change|
          summary << "- #{change.name}:"
          if change.key_changes.any?
            change.key_changes.take(5).each do |key_change|
              summary << "  #{key_change}"
            end
            summary << "  [...#{change.key_changes.size - 5} more changes omitted...]" if change.key_changes.size > 5
          else
            summary << "  #{change.additions} additions, #{change.deletions} deletions"
          end
        end

        summary << "\n[Note: Some context and minor changes have been omitted for brevity]"
        summary.join("\n")
      end

      def extract_file_name(line)
        line.match(%r{b/(.+)$})[1]
      end

      def key_change?(line)
        # Consider a change "key" if it matches certain patterns
        return true if line.match?(/^(class|module|def|private|protected|public)/)
        return true if line.match?(/^[A-Z][A-Za-z0-9_]*\s*=/) # Constants
        return true if line.match?(/^\s*attr_(reader|writer|accessor)/)
        return true if line.match?(/^\s*validates?/)
        return true if line.match?(/^\s*has_(many|one|and_belongs_to_many)/)
        return true if line.match?(/^\s*belongs_to/)

        false
      end
    end
  end
end
