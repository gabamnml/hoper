# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hoper/version'

Gem::Specification.new do |spec|
  spec.name          = "hoper"
  spec.version       = Hoper::VERSION
  spec.authors       = ["Gabriel Aramburu"]
  spec.email         = ["aramburu.gabriel@gmail.com"]

  spec.summary       = %q{Trace the URL's of a link.}
  spec.description   = %q{Trace URL's jumps across the rel links to obtain the last URL}
  spec.homepage      = "http://garamburu.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = ["hoper"]  
  # spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "curb"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
end
