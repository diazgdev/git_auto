# frozen_string_literal: true

module GitAuto
  module Errors
    class Error < StandardError; end
    class MissingAPIKeyError < Error; end
    class EmptyDiffError < Error; end
    class RateLimitError < Error; end
    class APIError < Error; end
    class InvalidProviderError < Error; end
  end
end
