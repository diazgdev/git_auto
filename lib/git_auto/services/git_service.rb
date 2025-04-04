# frozen_string_literal: true

require "English"

module GitAuto
  module Services
    class GitService
      class Error < StandardError; end

      def get_staged_diff(files = nil)
        validate_git_repository!
        if files
          files = [files] unless files.is_a?(Array)
          execute_git_command("diff", "--cached", "--", *files)
        else
          execute_git_command("diff", "--cached")
        end
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
        format = "%H%n%s%n%an%n%aI"
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
        return if File.directory?(".git")

        raise Error, "Not a git repository (or any of the parent directories)"
      end

      def validate_staged_changes!
        return if has_staged_changes?

        raise Error, "No changes staged for commit"
      end

      def has_staged_changes?
        # git diff --cached --quiet returns:
        # - exit status 0 (success) if there are no changes
        # - exit status 1 (failure) if there are changes
        system("git diff --cached --quiet")
        !$CHILD_STATUS.success?
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

        raise Error, "Git command failed: git #{args.join(" ")}\n#{output}" unless $CHILD_STATUS.success?

        output
      end
    end
  end
end
