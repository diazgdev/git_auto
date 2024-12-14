# frozen_string_literal: true

require "json"
require "fileutils"

module GitAuto
  module Services
    class HistoryService
      HISTORY_FILE = File.join(Config::Settings::CONFIG_DIR, "commit_history.json")
      MAX_HISTORY_ENTRIES = 10

      class Error < StandardError; end

      def initialize
        @settings = Config::Settings.new
        ensure_history_file
      end

      def save_commit(message, metadata = {})
        return unless @settings.get(:save_history)

        history = load_history
        history.unshift({
                          message: message,
                          timestamp: Time.now.iso8601,
                          metadata: metadata
                        })

        history = history.take(MAX_HISTORY_ENTRIES)

        save_history(history)
      end

      def get_recent_commits(limit = nil)
        history = load_history
        limit ? history.take(limit) : history
      end

      def analyze_patterns(limit = 50)
        history = load_history.take(limit)
        return {} if history.empty?

        {
          styles: analyze_styles(history),
          scopes: analyze_scopes(history),
          types: analyze_types(history),
          common_phrases: analyze_phrases(history)
        }
      end

      private

      def ensure_history_file
        return if File.exist?(HISTORY_FILE)

        FileUtils.mkdir_p(File.dirname(HISTORY_FILE))
        save_history([])
      end

      def load_history
        JSON.parse(File.read(HISTORY_FILE), symbolize_names: true)
      rescue JSON::ParserError, Errno::ENOENT
        []
      end

      def save_history(history)
        File.write(HISTORY_FILE, JSON.pretty_generate(history))
      rescue StandardError => e
        raise Error, "Failed to save commit history: #{e.message}"
      end

      def analyze_styles(history)
        styles = history.each_with_object(Hash.new(0)) do |entry, counts|
          style = detect_style(entry[:message])
          counts[style] += 1
        end

        total = styles.values.sum.to_f
        styles.transform_values { |count| (count / total * 100).round(1) }
      end

      def analyze_scopes(history)
        scopes = history.each_with_object(Hash.new(0)) do |entry, counts|
          scope = extract_scope(entry[:message])
          counts[scope] += 1 if scope
        end

        # Return top 10 most used scopes
        scopes.sort_by { |_, count| -count }.take(10).to_h
      end

      def analyze_types(history)
        types = history.each_with_object(Hash.new(0)) do |entry, counts|
          type = extract_type(entry[:message])
          counts[type] += 1 if type
        end

        total = types.values.sum.to_f
        types.transform_values { |count| (count / total * 100).round(1) }
      end

      def analyze_phrases(history)
        phrases = history.each_with_object(Hash.new(0)) do |entry, counts|
          extract_phrases(entry[:message]).each do |phrase|
            counts[phrase] += 1
          end
        end

        # Return top 10 most used phrases
        phrases.sort_by { |_, count| -count }.take(10).to_h
      end

      def detect_style(message)
        if message.match?(/^(feat|fix|docs|style|refactor|test|chore)(\([^)]+\))?:/)
          "conventional"
        elsif message.include?("\n\n")
          "detailed"
        else
          "simple"
        end
      end

      def extract_scope(message)
        if (match = message.match(/^[a-z]+\(([^)]+)\):/))
          match[1]
        end
      end

      def extract_type(message)
        if (match = message.match(/^([a-z]+)(\([^)]+\))?:/))
          match[1]
        end
      end

      def extract_phrases(message)
        content = message.sub(/^[a-z]+(\([^)]+\))?:\s*/, "")
        words = content.downcase.split(/[^a-z]+/).reject(&:empty?)

        phrases = []
        words.each_cons(2) { |phrase| phrases << phrase.join(" ") }
        words.each_cons(3) { |phrase| phrases << phrase.join(" ") }
        phrases
      end
    end
  end
end
