# frozen_string_literal: true

require_relative "lib/hoper/version"

Gem::Specification.new do |spec|
  spec.name          = "hoper"
  spec.version       = Hoper::VERSION
  spec.authors       = ["Gabriel Aramburu"]
  spec.email         = ["aramburu.gabriel@gmail.com"]

  spec.summary       = "Trace every redirect (hop) a URL goes through."
  spec.description   = "Hoper follows HTTP redirects step by step and shows each hop with its " \
                       "status code and timing, until the final URL. Pure Ruby, no native " \
                       "extensions: works on Linux, macOS and Windows."
  spec.homepage      = "https://github.com/gabamnml/hoper"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  # Avoid shelling out to git so the gem builds anywhere (e.g. Windows without git).
  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.bindir        = "exe"
  spec.executables   = ["hoper"]
  spec.require_paths = ["lib"]

  # Runtime: standard library only (net/http, uri, openssl, json, optparse).
end
