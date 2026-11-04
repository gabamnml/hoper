# frozen_string_literal: true

module Hoper
  # A single request/response in the redirect chain.
  Hop = Struct.new(:url, :status, :reason, :location, :duration_ms, keyword_init: true) do
    def redirect?
      !location.nil? && status.between?(300, 399)
    end

    def to_h
      super.compact
    end
  end
end
