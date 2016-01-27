# -*- encoding: utf-8 -*-
# stub: rest-gw2 0.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rest-gw2"
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Lin Jen-Shin (godfat)"]
  s.date = "2016-01-28"
  s.description = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)\nclient built with [rest-core](https://github.com/godfat/rest-core).\n\nThere's also a bundled web application showing your items, serving as an\nexample using the client."
  s.email = ["godfat (XD) godfat.org"]
  s.executables = ["rest-gw2"]
  s.files = [
  ".gitignore",
  ".gitmodules",
  "CHANGES.md",
  "LICENSE",
  "README.md",
  "Rakefile",
  "bin/rest-gw2",
  "config.ru",
  "lib/rest-gw2.rb",
  "lib/rest-gw2/client.rb",
  "lib/rest-gw2/server.rb",
  "lib/rest-gw2/server/cache.rb",
  "lib/rest-gw2/server/runner.rb",
  "lib/rest-gw2/version.rb",
  "lib/rest-gw2/view/characters.erb",
  "lib/rest-gw2/view/dyes.erb",
  "lib/rest-gw2/view/error.erb",
  "lib/rest-gw2/view/guild.erb",
  "lib/rest-gw2/view/index.erb",
  "lib/rest-gw2/view/info.erb",
  "lib/rest-gw2/view/item_list.erb",
  "lib/rest-gw2/view/item_show.erb",
  "lib/rest-gw2/view/items.erb",
  "lib/rest-gw2/view/items_from.erb",
  "lib/rest-gw2/view/layout.erb",
  "lib/rest-gw2/view/menu.erb",
  "lib/rest-gw2/view/menu_armors.erb",
  "lib/rest-gw2/view/menu_weapons.erb",
  "lib/rest-gw2/view/pages.erb",
  "lib/rest-gw2/view/profile.erb",
  "lib/rest-gw2/view/skins.erb",
  "lib/rest-gw2/view/transactions.erb",
  "lib/rest-gw2/view/wallet.erb",
  "lib/rest-gw2/view/wip.erb",
  "rest-gw2.gemspec",
  "task/README.md",
  "task/gemgem.rb"]
  s.homepage = "https://github.com/godfat/rest-gw2"
  s.licenses = ["Apache License 2.0"]
  s.rubygems_version = "2.5.1"
  s.summary = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-core>, [">= 4"])
      s.add_development_dependency(%q<jellyfish>, [">= 0"])
      s.add_development_dependency(%q<rack>, [">= 0"])
      s.add_development_dependency(%q<rack-handlers>, [">= 0"])
      s.add_development_dependency(%q<dalli>, [">= 0"])
      s.add_development_dependency(%q<lru_redux>, [">= 0"])
    else
      s.add_dependency(%q<rest-core>, [">= 4"])
      s.add_dependency(%q<jellyfish>, [">= 0"])
      s.add_dependency(%q<rack>, [">= 0"])
      s.add_dependency(%q<rack-handlers>, [">= 0"])
      s.add_dependency(%q<dalli>, [">= 0"])
      s.add_dependency(%q<lru_redux>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-core>, [">= 4"])
    s.add_dependency(%q<jellyfish>, [">= 0"])
    s.add_dependency(%q<rack>, [">= 0"])
    s.add_dependency(%q<rack-handlers>, [">= 0"])
    s.add_dependency(%q<dalli>, [">= 0"])
    s.add_dependency(%q<lru_redux>, [">= 0"])
  end
end
