# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'attributable/version'

Gem::Specification.new do |spec|
  spec.name          = "attributable"
  spec.version       = Attributable::VERSION
  spec.authors       = ["Kip Cole"]
  spec.email         = ["kipcole9@gmail.com"]
  spec.summary       = %q{Attribute definition and normalization abstraction}
  spec.description   = %q{Define attributes on an ActiveRecord model and their normalizations}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_dependency "attribute_normalizer"
  spec.add_dependency "twitter-text"
end
