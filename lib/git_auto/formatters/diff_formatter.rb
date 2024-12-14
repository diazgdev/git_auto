# frozen_string_literal: true

module GitAuto
  module Formatters
    class DiffFormatter
      def format(diff)
        return "No changes" if diff.empty?

        formatted = []
        current_file = nil

        diff.each_line do |line|
          case line
          when /^diff --git/
            current_file = extract_file_name(line)
            formatted << "\nChanges in #{current_file}:"
          when /^index |^---|\+\+\+/
            next
          when /^@@ .* @@/
            formatted << format_hunk_header(line)
          when /^\+/
            formatted << "Added: #{line[1..].strip}"
          when /^-/
            formatted << "Removed: #{line[1..].strip}"
          when /^ /
            formatted << "Context: #{line.strip}" unless line.strip.empty?
          end
        end

        formatted.join("\n")
      end

      private

      def extract_file_name(line)
        line.match(%r{b/(.+)$})[1]
      end

      def format_hunk_header(line)
        match = line.match(/@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@(.*)/)
        return line unless match

        line_info = "@ #{match[1]}-#{match[3]}"
        context = match[5].strip
        "\nSection #{line_info} #{context}"
      end
    end
  end
end
