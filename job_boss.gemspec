# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "job_boss"
  s.version     = '0.7.17'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Brian Underwood"]
  s.email       = ["ml+job_boss@semi-sentient.com"]
  s.homepage    = "http://github.com/cheerfulstoic/job_boss"
  s.summary     = %q{Asyncronous, parallel job processing}
  s.description = %q{job_boss allows you to queue jobs which are unqueued by a "Job Boss" daemon and handed off to workers to process}

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "activerecord"
  s.add_dependency "activesupport"
  s.add_dependency "daemons-mikehale"

  s.files              = `git ls-files`.split("\n")
  s.test_files         = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables        = %w(job_boss)
  s.default_executable = "job_boss"
  s.require_paths      = ["lib", "vendor", "vendor/spawn/lib"]
end
