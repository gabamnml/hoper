# frozen_string_literal: true

require_relative "hoper/version"
require_relative "hoper/hop"
require_relative "hoper/result"
require_relative "hoper/tracer"

# Hoper traces every redirect ("hop") a URL goes through until it reaches
# its final destination.
#
#   result = Hoper.trace("https://bit.ly/example")
#   result.hops.each { |hop| puts "#{hop.status} #{hop.url}" }
#   result.final_url # => "https://example.com/"
module Hoper
  class Error < StandardError; end
  class InvalidURLError < Error; end

  # Convenience wrapper around Hoper::Tracer.
  def self.trace(url, **options)
    Tracer.new(**options).trace(url)
  end
end
