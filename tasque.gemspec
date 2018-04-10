# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tasque/version'

Gem::Specification.new do |gem|
  gem.name          = "tasque"
  gem.version       = Tasque::VERSION
  gem.authors       = ["Yuri Gomozov"]
  gem.email         = ["grophen@gmail.com"]
  gem.description   = %q{Task processing queue with states, history and priorities. Works with your favorite database. }
  gem.summary       = %q{ActiveRecord based task queue}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_dependency("activerecord")
  gem.add_dependency("timers")
  gem.add_dependency("state_machine")
end
