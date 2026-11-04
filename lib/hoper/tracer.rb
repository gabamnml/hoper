# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module Hoper
  # Follows HTTP redirects one by one using only the Ruby standard library,
  # so it works the same on Linux, macOS and Windows without native
  # extensions. Proxies from HTTP_PROXY / HTTPS_PROXY / NO_PROXY are honoured.
  class Tracer
    DEFAULT_MAX_HOPS = 20
    DEFAULT_TIMEOUT = 10
    DEFAULT_USER_AGENT = "hoper/#{VERSION} (+https://github.com/gabamnml/hoper)".freeze
    SUPPORTED_METHODS = %w[HEAD GET].freeze
    # Servers that reject HEAD usually answer with one of these.
    HEAD_FALLBACK_STATUSES = [400, 403, 404, 405, 501].freeze

    attr_reader :max_hops, :timeout, :http_method, :user_agent, :verify_ssl, :headers

    def initialize(max_hops: DEFAULT_MAX_HOPS, timeout: DEFAULT_TIMEOUT, method: "HEAD",
                   user_agent: DEFAULT_USER_AGENT, verify_ssl: true, headers: {})
      @max_hops = Integer(max_hops)
      @timeout = Float(timeout)
      @http_method = method.to_s.upcase
      @user_agent = user_agent
      @verify_ssl = verify_ssl
      @headers = headers

      raise ArgumentError, "max_hops must be >= 1" if @max_hops < 1
      raise ArgumentError, "timeout must be > 0" unless @timeout.positive?
      return if SUPPORTED_METHODS.include?(@http_method)

      raise ArgumentError, "method must be one of #{SUPPORTED_METHODS.join(', ')}"
    end

    # Traces +url+ and yields each Hop as soon as it is known (if a block is
    # given). Always returns a Result; network failures are reported in
    # Result#error instead of being raised.
    def trace(url)
      uri = self.class.normalize(url)
      result = Result.new(start_url: uri.to_s, hops: [])
      seen = {}

      loop do
        if seen[uri.to_s]
          result.error = "Redirect loop detected at #{uri}"
          break
        end
        seen[uri.to_s] = true

        hop = request(uri)
        result.hops << hop
        yield hop if block_given?

        break unless hop.redirect?

        if result.redirect_count >= max_hops
          result.error = "Too many redirects (limit is #{max_hops})"
          break
        end

        uri = resolve_location(uri, hop.location)
      end

      result
    rescue InvalidURLError => e
      Result.new(start_url: url.to_s, hops: [], error: e.message)
    rescue StandardError => e
      result ||= Result.new(start_url: url.to_s, hops: [])
      result.error = describe_error(e, uri)
      result
    end

    # Turns user input into an absolute http(s) URI. A missing scheme
    # defaults to https.
    def self.normalize(url)
      input = url.to_s.strip
      raise InvalidURLError, "URL is empty" if input.empty?

      input = "https://#{input}" unless input.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
      uri = URI.parse(input)
      unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?
        raise InvalidURLError, "Not a valid http(s) URL: #{url}"
      end

      uri.path = "/" if uri.path.nil? || uri.path.empty?
      uri
    rescue URI::InvalidURIError
      raise InvalidURLError, "Not a valid http(s) URL: #{url}"
    end

    # Known bug: the system OpenSSL 3.6+ combined with an outdated `openssl`
    # Ruby gem fails every verification with "unable to get certificate CRL"
    # even for valid certificates. Updating the gem fixes it.
    def self.tls_hint(message)
      if message.include?("unable to get certificate CRL")
        "\n    Your Ruby 'openssl' gem (#{OpenSSL::VERSION}) is incompatible with " \
          "#{OpenSSL::OPENSSL_LIBRARY_VERSION}. Fix it with: gem update openssl"
      else
        " (use --insecure to skip verification)"
      end
    end

    private

    def request(uri)
      started = monotonic_ms
      response = perform(uri, http_method)
      if http_method == "HEAD" && HEAD_FALLBACK_STATUSES.include?(response.code.to_i)
        started = monotonic_ms
        response = perform(uri, "GET")
      end

      Hop.new(
        url: uri.to_s,
        status: response.code.to_i,
        reason: response.message.to_s.strip,
        location: response["location"],
        duration_ms: (monotonic_ms - started).round
      )
    end

    def perform(uri, verb)
      http = Net::HTTP.new(uri.host, uri.port) # proxy taken from ENV
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.write_timeout = timeout
      http.ssl_timeout = timeout if http.use_ssl?

      klass = verb == "HEAD" ? Net::HTTP::Head : Net::HTTP::Get
      req = klass.new(uri)
      req["User-Agent"] = user_agent
      req["Accept"] = "*/*"
      headers.each { |k, v| req[k] = v }

      http.start do |conn|
        # Don't download bodies: we only care about status and headers.
        conn.request(req) { |res| res.read_body { nil } if verb == "GET" }
      end
    end

    def resolve_location(base, location)
      target = URI.join(base.to_s, location.strip)
      raise Error, "Redirect to unsupported URL: #{location}" unless target.is_a?(URI::HTTP)

      target
    rescue URI::Error
      # Some servers send unescaped characters in Location.
      URI.join(base.to_s, URI::DEFAULT_PARSER.escape(location.strip))
    end

    def describe_error(error, uri)
      where = uri ? " (#{uri.host})" : ""
      case error
      when SocketError
        "Could not resolve host#{where}"
      when Errno::ECONNREFUSED
        "Connection refused#{where}"
      when Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error
        "Timed out after #{timeout}s#{where}"
      when OpenSSL::SSL::SSLError
        "TLS error#{where}: #{error.message}#{self.class.tls_hint(error.message)}"
      else
        "#{error.class}: #{error.message}"
      end
    end

    def monotonic_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
