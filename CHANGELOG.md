# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2024-12-19

### Fixed
- Improve Claude AI response handling for conventional commit messages
- Make system prompts more explicit to ensure consistent output format
- Fixed error when displaying repository status with no staged files
- Improved error handling in repository status display

### Changed
- Update system prompts to be more strict and specific
- Enhance commit message validation for Claude responses

## [0.2.0] - 2024-12-15

### Added
- Support for multiple AI providers (OpenAI and Anthropic)
- New commit message styles (minimal, conventional, simple)
- Commit history analysis
- Pattern detection for commit types and scopes
- Secure API key storage with encryption

### Changed
- Improved error messages and validation
- Enhanced diff formatting and preview
- Better handling of commit message generation

### Fixed
- Various bug fixes and performance improvements

## [0.1.1] - 2024-12-13

- Remove debug logging output from API requests for cleaner user experience
- Add commented debugging options for developers

## [0.1.0] - 2024-12-12

- Initial release
