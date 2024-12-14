# frozen_string_literal: true

module GitAuto
  module Commands
    class HistoryAnalysisCommand
      def initialize(options = {})
        @limit = options[:limit] || 10
        @git_service = Services::GitService.new
        @prompt = TTY::Prompt.new
        @spinner = TTY::Spinner.new("[:spinner] Analyzing commit history...")
      end

      def execute
        @spinner.auto_spin
        commits = fetch_commits
        analysis = analyze_commits(commits)
        @spinner.success
        display_results(analysis)
      rescue StandardError => e
        puts "❌ Error analyzing commits: #{e.message}".red
        exit 1
      end

      private

      def fetch_commits
        @git_service.get_commit_history(@limit)
      end

      def analyze_commits(commits)
        {
          total_commits: commits.size,
          types: analyze_types(commits),
          avg_length: average_message_length(commits),
          common_patterns: find_common_patterns(commits)
        }
      end

      def analyze_types(commits)
        commits.each_with_object(Hash.new(0)) do |commit, types|
          type = extract_type(commit)
          types[type] += 1
        end
      end

      def extract_type(commit)
        return "conventional" if commit.match?(/^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?:/)
        return "detailed" if commit.include?("\n\n")

        "simple"
      end

      def average_message_length(commits)
        return 0 if commits.empty?

        commits.sum(&:length) / commits.size
      end

      def find_common_patterns(commits)
        words = commits.flat_map { |c| c.downcase.scan(/\w+/) }
        words.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
          .sort_by { |_, count| -count }
          .first(5)
          .to_h
      end

      def display_results(analysis)
        puts "\n📊 Commit History Analysis".blue
        puts "Total commits analyzed: #{analysis[:total_commits]}"

        puts "\n📝 Commit Types:".blue
        analysis[:types].each do |type, count|
          percentage = (count.to_f / analysis[:total_commits] * 100).round(1)
          puts "#{type}: #{count} (#{percentage}%)"
        end

        puts "\n📈 Statistics:".blue
        puts "Average message length: #{analysis[:avg_length]} characters"

        puts "\n🔍 Common words:".blue
        analysis[:common_patterns].each do |word, count|
          puts "#{word}: #{count} times"
        end
      end
    end
  end
end
