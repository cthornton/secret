# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'secret/version'

Gem::Specification.new do |spec|
  spec.name          = "secret"
  spec.version       = Secret::VERSION
  spec.authors       = ["Christopher Thornton"]
  spec.email         = ["rmdirbin@gmail.com"]
  spec.description   = %q{Keeps your files more secure by ensuring saved files are chmoded 0700 by the same user who is running the process.}
  spec.summary       = %q{Keeps files more secure on server environments}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
