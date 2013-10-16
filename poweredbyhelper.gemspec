# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "poweredbyhelper"
  s.version     = "0.0.1"
  s.authors     = ["Adrian Toman"]
  s.email       = ["adrian.toman@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Provisioning of PoweredBy projects}
  s.description = %q{MS Infratructure}

  s.rubyforge_project = "poweredbyhelper"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:

  s.add_dependency "gooddata","=0.5.14"
  s.add_dependency "gli", "~> 2.7.0"
  s.add_dependency "pry"
  s.add_dependency "fastercsv", "~> 1.5.5"
  s.add_dependency "colorize"
end
