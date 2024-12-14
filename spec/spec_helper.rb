# frozen_string_literal: true

require "bundler/setup"
require "git_auto"
require "vcr"
require "webmock/rspec"

ENV["RACK_ENV"] = "test"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter sensitive data
  config.filter_sensitive_data("<OPENAI_API_KEY>") do |interaction|
    Regexp.last_match(1) if interaction.request.headers["Authorization"]&.first =~ /^Bearer (sk-\w+)$/
  end
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") do |interaction|
    interaction.request.headers["X-Api-Key"]&.first
  end

  # Configure VCR to ignore non-deterministic headers
  config.before_record do |interaction|
    interaction.response.headers.delete("Set-Cookie")
    interaction.response.headers.delete("X-Request-Id")
    interaction.response.headers.delete("CF-Ray")
    interaction.response.headers.delete("cf-request-id")
    interaction.response.headers.delete("Server")
    interaction.response.headers.delete("Alt-Svc")
    interaction.response.headers.delete("Via")
    interaction.response.headers.delete("CF-Cache-Status")
    interaction.response.headers.delete("Vary")
  end

  # Allow VCR to record new HTTP interactions when no cassette exists
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri],
    allow_unused_http_interactions: true,
    decode_compressed_response: true,
    serialize_with: :yaml
  }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    ENV["RACK_ENV"] = "test"
  end

  config.around do |example|
    cassette_name = example.metadata[:cassette_name] || example.metadata[:full_description].split(/\s+/, 2).join("/").downcase.gsub(
      %r{[^\w/]+}, "_"
    )
    VCR.use_cassette(cassette_name) { example.run }
  end
end
