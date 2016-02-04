# -*- encoding: utf-8 -*-
# stub: rest-gw2 0.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rest-gw2".freeze
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Lin Jen-Shin (godfat)".freeze]
  s.date = "2016-02-05"
  s.description = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)\nclient built with [rest-core](https://github.com/godfat/rest-core).\n\nThere's also a bundled web application showing your items, serving as an\nexample using the client.".freeze
  s.email = ["godfat (XD) godfat.org".freeze]
  s.executables = ["rest-gw2".freeze]
  s.files = [
  ".gitignore".freeze,
  ".gitmodules".freeze,
  "CHANGES.md".freeze,
  "LICENSE".freeze,
  "README.md".freeze,
  "Rakefile".freeze,
  "bin/rest-gw2".freeze,
  "config.ru".freeze,
  "lib/rest-gw2.rb".freeze,
  "lib/rest-gw2/client.rb".freeze,
  "lib/rest-gw2/server.rb".freeze,
  "lib/rest-gw2/server/cache.rb".freeze,
  "lib/rest-gw2/server/runner.rb".freeze,
  "lib/rest-gw2/version.rb".freeze,
  "lib/rest-gw2/view/characters.erb".freeze,
  "lib/rest-gw2/view/dyes.erb".freeze,
  "lib/rest-gw2/view/error.erb".freeze,
  "lib/rest-gw2/view/guild.erb".freeze,
  "lib/rest-gw2/view/index.erb".freeze,
  "lib/rest-gw2/view/info.erb".freeze,
  "lib/rest-gw2/view/item_list.erb".freeze,
  "lib/rest-gw2/view/item_show.erb".freeze,
  "lib/rest-gw2/view/items.erb".freeze,
  "lib/rest-gw2/view/items_from.erb".freeze,
  "lib/rest-gw2/view/layout.erb".freeze,
  "lib/rest-gw2/view/menu.erb".freeze,
  "lib/rest-gw2/view/menu_armors.erb".freeze,
  "lib/rest-gw2/view/menu_weapons.erb".freeze,
  "lib/rest-gw2/view/pages.erb".freeze,
  "lib/rest-gw2/view/profile.erb".freeze,
  "lib/rest-gw2/view/skins.erb".freeze,
  "lib/rest-gw2/view/transactions.erb".freeze,
  "lib/rest-gw2/view/wallet.erb".freeze,
  "lib/rest-gw2/view/wip.erb".freeze,
  "rest-gw2.gemspec".freeze,
  "task/README.md".freeze,
  "task/gemgem.rb".freeze]
  s.homepage = "https://github.com/godfat/rest-gw2".freeze
  s.licenses = ["Apache License 2.0".freeze]
  s.rubygems_version = "2.5.2".freeze
  s.summary = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-core>.freeze, [">= 4.0.0"])
      s.add_development_dependency(%q<jellyfish>.freeze, [">= 0"])
      s.add_development_dependency(%q<rack>.freeze, [">= 0"])
      s.add_development_dependency(%q<rack-handlers>.freeze, [">= 0"])
      s.add_development_dependency(%q<dalli>.freeze, [">= 0"])
      s.add_development_dependency(%q<lru_redux>.freeze, [">= 0"])
    else
      s.add_dependency(%q<rest-core>.freeze, [">= 4.0.0"])
      s.add_dependency(%q<jellyfish>.freeze, [">= 0"])
      s.add_dependency(%q<rack>.freeze, [">= 0"])
      s.add_dependency(%q<rack-handlers>.freeze, [">= 0"])
      s.add_dependency(%q<dalli>.freeze, [">= 0"])
      s.add_dependency(%q<lru_redux>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-core>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<jellyfish>.freeze, [">= 0"])
    s.add_dependency(%q<rack>.freeze, [">= 0"])
    s.add_dependency(%q<rack-handlers>.freeze, [">= 0"])
    s.add_dependency(%q<dalli>.freeze, [">= 0"])
    s.add_dependency(%q<lru_redux>.freeze, [">= 0"])
  end
end
