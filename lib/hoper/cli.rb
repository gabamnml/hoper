# frozen_string_literal: true

require "json"
require "optparse"
require_relative "../hoper"

module Hoper
  # Command line interface: `hoper [options] URL...`
  class CLI
    EXIT_OK = 0
    EXIT_FAILURE = 1
    EXIT_USAGE = 2

    COLORS = { red: 31, green: 32, yellow: 33, blue: 34, cyan: 36, gray: 90, bold: 1 }.freeze

    def self.start(argv = ARGV, out: $stdout, err: $stderr)
      new(out: out, err: err).run(argv)
    end

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
      @options = {
        format: :text,
        color: color_supported?(out),
        tracer: {}
      }
    end

    def run(argv)
      catch(:done) { execute(argv) }
    end

    private

    def execute(argv)
      urls = parser.parse(argv.dup)
      if urls.empty?
        @err.puts parser.help
        return EXIT_USAGE
      end

      tracer = Tracer.new(**@options[:tracer])
      results = urls.map { |url| @options[:format] == :json ? tracer.trace(url) : trace_text(tracer, url) }
      print_json(results) if @options[:format] == :json
      results.all?(&:success?) ? EXIT_OK : EXIT_FAILURE
    rescue OptionParser::ParseError, ArgumentError => e
      @err.puts "hoper: #{e.message}"
      @err.puts "Try 'hoper --help' for more information."
      EXIT_USAGE
    rescue Interrupt
      @err.puts
      130
    end

    def parser
      @parser ||= OptionParser.new do |o|
        o.banner = "Usage: hoper [options] URL [URL...]"
        o.separator ""
        o.separator "Show every redirect (hop) a URL goes through until its final destination."
        o.separator ""
        o.separator "Options:"
        o.on("-m", "--max-hops N", Integer, "Maximum redirects to follow (default: #{Tracer::DEFAULT_MAX_HOPS})") do |n|
          @options[:tracer][:max_hops] = n
        end
        o.on("-t", "--timeout SECONDS", Float, "Timeout per request (default: #{Tracer::DEFAULT_TIMEOUT})") do |t|
          @options[:tracer][:timeout] = t
        end
        o.on("-X", "--method METHOD", Tracer::SUPPORTED_METHODS, "HTTP method: HEAD or GET (default: HEAD)") do |m|
          @options[:tracer][:method] = m
        end
        o.on("-A", "--user-agent UA", "User-Agent header to send") { |ua| @options[:tracer][:user_agent] = ua }
        o.on("-H", "--header 'NAME: VALUE'", "Extra request header (repeatable)") do |h|
          name, value = h.split(":", 2).map(&:strip)
          raise OptionParser::InvalidArgument, h if name.to_s.empty? || value.nil?

          (@options[:tracer][:headers] ||= {})[name] = value
        end
        o.on("-k", "--insecure", "Do not verify TLS certificates") { @options[:tracer][:verify_ssl] = false }
        o.on("-j", "--json", "Output results as JSON") { @options[:format] = :json }
        o.on("--[no-]color", "Force/disable colored output") { |c| @options[:color] = c }
        o.on("-v", "--version", "Print version and exit") do
          @out.puts "hoper #{VERSION}"
          throw :done, EXIT_OK
        end
        o.on("-h", "--help", "Show this help") do
          @out.puts o.help
          throw :done, EXIT_OK
        end
        o.separator ""
        o.separator "Examples:"
        o.separator "  hoper https://bit.ly/3abcd"
        o.separator "  hoper -X GET --json example.com"
        o.separator ""
        o.separator "Proxies are read from HTTP_PROXY / HTTPS_PROXY / NO_PROXY."
      end
    end

    def trace_text(tracer, url)
      @out.puts paint("Tracing #{url}", :bold)
      index = 0
      result = tracer.trace(url) do |hop|
        index += 1
        @out.puts format_hop(index, hop)
      end
      @out.puts summary(result)
      @out.puts
      result
    end

    def format_hop(index, hop)
      status = paint("#{hop.status} #{hop.reason}".strip, status_color(hop.status))
      time = paint("#{hop.duration_ms}ms", :gray)
      marker = hop.redirect? ? paint(symbol(:arrow), :cyan) : paint(symbol(:check), status_color(hop.status))
      "  #{index.to_s.rjust(2)}. #{marker} #{status}  #{hop.url}  #{time}"
    end

    def summary(result)
      if result.error
        "  #{paint("#{symbol(:cross)} #{result.error}", :red)}"
      else
        hops = result.redirect_count
        word = hops == 1 ? "redirect" : "redirects"
        "  #{paint("#{hops} #{word}", :bold)} #{symbol(:arrow)} #{paint(result.final_url, status_color(result.final_status))}"
      end
    end

    # Legacy Windows consoles (non UTF-8 code pages) can't show these glyphs.
    def symbol(name)
      unicode = { arrow: "→", check: "✔", cross: "✖" }
      ascii = { arrow: "->", check: "OK", cross: "x" }
      encoding = @out.respond_to?(:external_encoding) && @out.external_encoding || Encoding.default_external
      (encoding == Encoding::UTF_8 ? unicode : ascii).fetch(name)
    end

    def print_json(results)
      data = results.map(&:to_h)
      @out.puts JSON.pretty_generate(data.size == 1 ? data.first : data)
    end

    def status_color(status)
      case status
      when 200..299 then :green
      when 300..399 then :yellow
      else :red
      end
    end

    def paint(text, color)
      return text unless @options[:color]

      "\e[#{COLORS.fetch(color)}m#{text}\e[0m"
    end

    # Respects https://no-color.org and only colors real terminals.
    # Windows 10+ terminals understand ANSI escape codes.
    def color_supported?(io)
      return false if ENV.key?("NO_COLOR")
      return true if ENV.key?("FORCE_COLOR")

      io.respond_to?(:tty?) && io.tty? && ENV["TERM"] != "dumb"
    end
  end
end
