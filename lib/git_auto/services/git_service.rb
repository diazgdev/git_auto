# frozen_string_literal: true

require "English"

module GitAuto
  module Services
    class GitService
      class Error < StandardError; end

      def get_staged_diff
        validate_git_repository!
        execute_git_command("diff", "--cached")
      end

      def get_staged_files
        validate_git_repository!
        execute_git_command("diff", "--cached", "--name-only").split("\n")
      end

      def commit(message)
        validate_git_repository!
        validate_staged_changes!
        first_line = message.split("\n").first.strip
        execute_git_command("commit", "-m", first_line)
      end

      def get_commit_history(limit = nil)
        validate_git_repository!
        format = '%H%n%s%n%an%n%aI'
        command = ["log", "--pretty=format:#{format}", "--no-merges"]
        command << "-#{limit}" if limit

        output = execute_git_command(*command)
        return [] if output.empty?

        output.split("\n\n").map do |commit|
          hash, subject, author, date = commit.split("\n")
          {
            hash: hash,
            subject: subject,
            author: author,
            date: date
          }
        end
      end

      def repository_status
        {
          has_staged_changes: has_staged_changes?,
          is_clean: is_clean?,
          has_commits: has_commits?
        }
      end

      private

      def validate_git_repository!
        unless File.directory?(".git")
          raise Error, "Not a git repository (or any of the parent directories)"
        end
      end

      def validate_staged_changes!
        unless has_staged_changes?
          raise Error, "No changes staged for commit"
        end
      end

      def has_staged_changes?
        !execute_git_command("diff", "--cached", "--quiet")
        $CHILD_STATUS.exitstatus == 1
      end

      def is_clean?
        execute_git_command("status", "--porcelain").empty?
      end

      def has_commits?
        execute_git_command("rev-parse", "--verify", "HEAD")
        true
      rescue StandardError
        false
      end

      def execute_git_command(*args)
        output = IO.popen(["git", *args], err: [:child, :out], &:read)

        unless $CHILD_STATUS.success?
          raise Error, "Git command failed: git #{args.join(' ')}\n#{output}"
        end

        output
      end
    end
  end
end
