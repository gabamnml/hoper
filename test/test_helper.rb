# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Tests talk to a local server only; never go through a proxy.
%w[http_proxy HTTP_PROXY https_proxy HTTPS_PROXY].each { |k| ENV.delete(k) }

require "hoper"
require "hoper/cli"
require "minitest/autorun"
require "socket"
require "stringio"

# Minimal threaded HTTP server so tests run offline on any OS
# (WEBrick is no longer part of the standard library).
class TestServer
  attr_reader :port, :requests

  # routes: { "/path" => [status, { "Header" => "value" }] }
  def initialize(routes)
    @routes = routes
    @requests = []
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def url(path = "/")
    "http://127.0.0.1:#{port}#{path}"
  end

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve
    loop do
      client = @server.accept
      handle(client)
    rescue IOError, Errno::EBADF
      break
    end
  end

  def handle(client)
    request_line = client.gets.to_s
    verb, path = request_line.split
    while (line = client.gets) && line != "\r\n"; end
    @requests << [verb, path]

    status, headers = @routes.fetch(path, [404, {}])
    status, headers = status.call(verb) if status.respond_to?(:call)
    body = verb == "HEAD" ? "" : "ok"
    client.write "HTTP/1.1 #{status} Status\r\n"
    headers.merge("Content-Length" => "2", "Connection" => "close").each { |k, v| client.write "#{k}: #{v}\r\n" }
    client.write "\r\n#{body}"
  ensure
    client&.close
  end
end
