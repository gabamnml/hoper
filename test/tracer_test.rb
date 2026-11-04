# frozen_string_literal: true

require_relative "test_helper"

class TracerTest < Minitest::Test
  def teardown
    @server&.stop
  end

  def serve(routes)
    @server = TestServer.new(routes)
  end

  def test_follows_redirect_chain
    serve(
      "/a" => [301, { "Location" => "/b" }],
      "/b" => [302, { "Location" => "/c" }],
      "/c" => [200, {}]
    )
    result = Hoper.trace(@server.url("/a"))

    assert result.success?
    assert_equal 2, result.redirect_count
    assert_equal [301, 302, 200], result.hops.map(&:status)
    assert_equal @server.url("/c"), result.final_url
  end

  def test_yields_each_hop
    serve("/a" => [307, { "Location" => "/b" }], "/b" => [200, {}])
    seen = []
    Hoper::Tracer.new.trace(@server.url("/a")) { |hop| seen << hop.status }
    assert_equal [307, 200], seen
  end

  def test_detects_loops
    serve("/a" => [302, { "Location" => "/b" }], "/b" => [302, { "Location" => "/a" }])
    result = Hoper.trace(@server.url("/a"))

    refute result.success?
    assert_match(/loop/i, result.error)
  end

  def test_respects_max_hops
    routes = (1..5).to_h { |i| ["/#{i}", [302, { "Location" => "/#{i + 1}" }]] }
    serve(routes)
    result = Hoper.trace(@server.url("/1"), max_hops: 2)

    assert_match(/too many redirects/i, result.error)
    assert_equal 2, result.redirect_count
  end

  def test_falls_back_to_get_when_head_not_allowed
    serve("/a" => [->(verb) { verb == "HEAD" ? [405, {}] : [200, {}] }, nil])
    result = Hoper.trace(@server.url("/a"))

    assert result.success?
    assert_equal [%w[HEAD /a], %w[GET /a]], @server.requests
  end

  def test_get_method
    serve("/a" => [200, {}])
    Hoper.trace(@server.url("/a"), method: "GET")
    assert_equal [%w[GET /a]], @server.requests
  end

  def test_error_status_is_not_success
    serve("/a" => [302, { "Location" => "/missing" }])
    result = Hoper.trace(@server.url("/a"), method: "GET")

    refute result.success?
    assert_nil result.error
    assert_equal 404, result.final_status
  end

  def test_connection_refused_is_reported
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    result = Hoper.trace("http://127.0.0.1:#{port}/", timeout: 2)

    refute result.success?
    assert_match(/refused|timed out/i, result.error)
  end

  def test_normalize_adds_https_scheme
    assert_equal "https://example.com/", Hoper::Tracer.normalize("example.com").to_s
    assert_equal "http://example.com/x?y=1", Hoper::Tracer.normalize(" http://example.com/x?y=1 ").to_s
  end

  def test_invalid_urls
    assert_match(/empty/, Hoper.trace("").error)
    assert_match(/valid/, Hoper.trace("ftp://example.com").error)
  end

  def test_rejects_bad_options
    assert_raises(ArgumentError) { Hoper::Tracer.new(method: "POST") }
    assert_raises(ArgumentError) { Hoper::Tracer.new(max_hops: 0) }
  end

  def test_tls_hint_for_openssl_crl_bug
    hint = Hoper::Tracer.tls_hint("certificate verify failed (unable to get certificate CRL)")
    assert_includes hint, "gem update openssl"
    refute_includes hint, "--insecure"
  end

  def test_tls_hint_default
    assert_includes Hoper::Tracer.tls_hint("certificate verify failed (self signed certificate)"), "--insecure"
  end
end
