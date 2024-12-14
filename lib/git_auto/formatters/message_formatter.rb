# frozen_string_literal: true

module GitAuto
  module Formatters
    class MessageFormatter
      HEADER_MAX_LENGTH = 72
      BODY_LINE_MAX_LENGTH = 80

      def format(message)
        return nil if message.nil? || message.strip.empty?

        message.strip
      end

      private

      def parse(message)
        return {} if message.nil? || message.strip.empty?

        { header: message.strip }
      end

      def format_header(header)
        return nil unless header

        match = header.match(/^(\w+)(\(.+\))?: (.+)/)

        if match
          type, scope, desc = match.captures
          "#{type.green}#{scope&.blue}: #{desc}"
        else
          header.yellow
        end
      end

      def format_body(body)
        return nil unless body

        wrap_text(body)
      end

      def format_footer(footer)
        return nil unless footer

        footer.red
      end

      def wrap_text(text, width = BODY_LINE_MAX_LENGTH)
        text.gsub(/(.{1,#{width}})(\s+|$)/, "\\1\n").strip
      end
    end
  end
end
