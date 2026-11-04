# Changelog

## 1.0.0

Complete modernization.

### Breaking
- Requires Ruby >= 3.1.
- Dropped the `curb` (libcurl) dependency: Hoper now uses only the Ruby standard library and
  installs on Windows, macOS and Linux without compilers or native libraries.
- New output format (one line per hop with status code and timing).

### Added
- Options: `--max-hops`, `--timeout`, `--method`, `--user-agent`, `--header`, `--insecure`,
  `--json`, `--[no-]color`, `--version`, `--help`.
- Multiple URLs per invocation.
- Redirect loop detection, relative `Location` handling, `HEAD` → `GET` fallback.
- Exit codes (0 ok, 1 failure, 2 usage).
- `Hoper.trace` library API.
- Test suite and GitHub Actions CI on Linux, macOS and Windows.

### Fixed
- Executable shebang (`#!/usr/bin/env ruby -wU`) failed on Linux.
- Errors were swallowed and always reported as "Bad URL".

## 0.1.1
- Previous release based on `curb`.
