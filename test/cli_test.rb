# frozen_string_literal: true

require_relative "test_helper"
require "json"

class CLITest < Minitest::Test
  def setup
    @server = TestServer.new("/a" => [301, { "Location" => "/b" }], "/b" => [200, {}])
  end

  def teardown
    @server.stop
  end

  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    code = Hoper::CLI.start(argv, out: out, err: err)
    [code, out.string, err.string]
  end

  def test_text_output
    code, out, = run_cli("--no-color", @server.url("/a"))

    assert_equal 0, code
    assert_includes out, "301"
    assert_includes out, @server.url("/b")
    assert_includes out, "1 redirect"
    refute_includes out, "\e["
  end

  def test_json_output
    code, out, = run_cli("--json", @server.url("/a"))
    data = JSON.parse(out)

    assert_equal 0, code
    assert_equal @server.url("/b"), data["final_url"]
    assert_equal 1, data["redirects"]
    assert_equal [301, 200], data["hops"].map { |h| h["status"] }
  end

  def test_multiple_urls_json_is_array
    _, out, = run_cli("--json", @server.url("/a"), @server.url("/b"))
    assert_equal 2, JSON.parse(out).size
  end

  def test_failure_exit_code
    code, = run_cli("--no-color", @server.url("/nope"))
    assert_equal 1, code
  end

  def test_usage_without_url
    code, _, err = run_cli
    assert_equal 2, code
    assert_includes err, "Usage"
  end

  def test_version
    code, out, = run_cli("--version")
    assert_equal 0, code
    assert_equal "hoper #{Hoper::VERSION}\n", out
  end

  def test_invalid_option
    code, _, err = run_cli("--bogus")
    assert_equal 2, code
    assert_includes err, "invalid option"
  end

  def test_invalid_header
    code, = run_cli("-H", "broken", @server.url("/a"))
    assert_equal 2, code
  end
end
