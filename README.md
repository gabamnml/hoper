# Hoper

[![Gem Version](https://badge.fury.io/rb/hoper.svg)](https://badge.fury.io/rb/hoper)
[![CI](https://github.com/gabamnml/hoper/actions/workflows/ci.yml/badge.svg)](https://github.com/gabamnml/hoper/actions/workflows/ci.yml)

Hoper shows every hop (redirect) a URL goes through until it reaches its final destination —
useful for URL shorteners, tracking links in emails, SSO flows, or debugging redirect rules.

```
$ hoper http://github.com
Tracing http://github.com
   1. → 301 Moved Permanently  http://github.com/  81ms
   2. ✔ 200 OK  https://github.com/  50ms
  1 redirect → https://github.com/
```

## Features

- **Works on Linux, macOS and Windows** — pure Ruby, no native extensions or libcurl required.
- Status code, reason and response time for every hop.
- Redirect loop detection and a configurable hop limit.
- Uses `HEAD` by default (no body downloads) with automatic fallback to `GET` for servers that reject it.
- JSON output for scripts and pipelines; meaningful exit codes.
- Honours `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` and [`NO_COLOR`](https://no-color.org).

## Installation

Requires Ruby 3.1 or newer.

```bash
gem install hoper
```

On Windows, install Ruby with [RubyInstaller](https://rubyinstaller.org/) and then run the same command.

## Usage

```
hoper [options] URL [URL...]

    -m, --max-hops N                 Maximum redirects to follow (default: 20)
    -t, --timeout SECONDS            Timeout per request (default: 10)
    -X, --method METHOD              HTTP method: HEAD or GET (default: HEAD)
    -A, --user-agent UA              User-Agent header to send
    -H, --header 'NAME: VALUE'       Extra request header (repeatable)
    -k, --insecure                   Do not verify TLS certificates
    -j, --json                       Output results as JSON
        --[no-]color                 Force/disable colored output
    -v, --version                    Print version and exit
    -h, --help                       Show this help
```

If the scheme is omitted, `https://` is assumed (`hoper example.com`).

### JSON output

```bash
hoper --json http://github.com
```

```json
{
  "start_url": "http://github.com/",
  "final_url": "https://github.com/",
  "final_status": 200,
  "redirects": 1,
  "hops": [
    { "url": "http://github.com/", "status": 301, "reason": "Moved Permanently", "location": "https://github.com/", "duration_ms": 81 },
    { "url": "https://github.com/", "status": 200, "reason": "OK", "duration_ms": 50 }
  ]
}
```

With several URLs the output is an array.

### Exit codes

| Code | Meaning |
|------|---------|
| 0    | Every URL resolved to a non-error (< 400) final response |
| 1    | At least one URL failed (network error, loop, too many hops, 4xx/5xx) |
| 2    | Invalid usage / options |

### As a library

```ruby
require "hoper"

result = Hoper.trace("https://bit.ly/example", max_hops: 10)
result.hops.each { |hop| puts "#{hop.status} #{hop.url}" }
result.final_url  # => "https://example.com/"
result.success?   # => true
```

## Development

```bash
bundle install
bundle exec rake test
```

CI runs the test suite on Ubuntu, macOS and Windows against Ruby 3.1–3.4. Tests use a local
in-process HTTP server, so they don't need network access.

To release a new version, update `lib/hoper/version.rb` and `CHANGELOG.md`, then run
`bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gabamnml/hoper. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
