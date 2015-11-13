# -*- encoding: utf-8 -*-
# stub: rest-gw2 0.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rest-gw2"
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Lin Jen-Shin (godfat)"]
  s.date = "2015-11-14"
  s.description = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)\nclient built with [rest-core](https://github.com/godfat/rest-core).\n\nThere's also a bundled web application showing your items, serving as an\nexample using the client."
  s.email = ["godfat (XD) godfat.org"]
  s.files = [
  ".gitignore",
  ".gitmodules",
  "README.md",
  "Rakefile",
  "config.ru",
  "lib/rest-gw2.rb",
  "lib/rest-gw2/client.rb",
  "lib/rest-gw2/server.rb",
  "lib/rest-gw2/view/bank.erb",
  "rest-gw2.gemspec",
  "task/README.md",
  "task/gemgem.rb"]
  s.homepage = "https://github.com/godfat/rest-gw2"
  s.licenses = ["Apache License 2.0"]
  s.rubygems_version = "2.5.0"
  s.summary = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-core>, [">= 0"])
    else
      s.add_dependency(%q<rest-core>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-core>, [">= 0"])
  end
end
