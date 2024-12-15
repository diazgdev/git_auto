# frozen_string_literal: true

require_relative "lib/git_auto/version"

Gem::Specification.new do |spec|
  spec.name = "git_auto"
  spec.version = GitAuto::VERSION
  spec.authors = ["Guillermo Diaz"]
  spec.email = ["diazgdev@gmail.com"]

  spec.summary = "AI-powered git commit messages using OpenAI or Anthropic APIs"
  spec.description = "GitAuto streamlines your git workflow by automatically generating meaningful commit messages using AI. It analyzes staged changes and generates conventional commit messages that are clear, consistent, and informative."
  spec.homepage = "https://github.com/diazgdev/git_auto"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/diazgdev/git_auto"
  spec.metadata["changelog_uri"] = "https://github.com/diazgdev/git_auto/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
    LICENSE.txt
    README.md
    CHANGELOG.md
    lib/**/*
    exe/**/*
  ])
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.3"        # CLI framework
  spec.add_dependency "tty-prompt", "~> 0.23"  # Interactive prompts
  spec.add_dependency "tty-spinner", "~> 0.9"  # Loading animations
  spec.add_dependency "colorize", "~> 1.1"     # Colorized output
  spec.add_dependency "http", "~> 5.1"         # HTTP client
  spec.add_dependency "clipboard", "~> 1.3"    # Clipboard support

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "rubocop-rspec", "~> 2.22"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "webmock", "~> 3.18"
end
