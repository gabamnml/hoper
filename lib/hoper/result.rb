# frozen_string_literal: true

module Hoper
  # Outcome of tracing a URL: the list of hops plus an optional error.
  Result = Struct.new(:start_url, :hops, :error, keyword_init: true) do
    def final_url
      hops.last&.url
    end

    def final_status
      hops.last&.status
    end

    # Number of redirects followed (the final response is not a hop).
    def redirect_count
      hops.count(&:redirect?)
    end

    def success?
      error.nil? && !final_status.nil? && final_status < 400
    end

    def to_h
      {
        start_url: start_url,
        final_url: final_url,
        final_status: final_status,
        redirects: redirect_count,
        hops: hops.map(&:to_h),
        error: error
      }.compact
    end
  end
end
