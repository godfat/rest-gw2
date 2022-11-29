# -*- encoding: utf-8 -*-
# stub: rest-gw2 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rest-gw2".freeze
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Lin Jen-Shin (godfat)".freeze]
  s.date = "2022-11-29"
  s.description = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)\nclient built with [rest-core](https://github.com/godfat/rest-core).\n\nThere's also a bundled web application showing your items, serving as an\nexample using the client. There's also a [demo site](https://gw2.godfat.org/)".freeze
  s.email = ["godfat (XD) godfat.org".freeze]
  s.executables = ["rest-gw2".freeze]
  s.files = [
  ".gitignore".freeze,
  ".gitmodules".freeze,
  "CHANGES.md".freeze,
  "LICENSE".freeze,
  "README.md".freeze,
  "Rakefile".freeze,
  "TODO.md".freeze,
  "bin/rest-gw2".freeze,
  "config.ru".freeze,
  "lib/rest-gw2.rb".freeze,
  "lib/rest-gw2/client.rb".freeze,
  "lib/rest-gw2/client/item_detail.rb".freeze,
  "lib/rest-gw2/server.rb".freeze,
  "lib/rest-gw2/server/action.rb".freeze,
  "lib/rest-gw2/server/cache.rb".freeze,
  "lib/rest-gw2/server/imp.rb".freeze,
  "lib/rest-gw2/server/runner.rb".freeze,
  "lib/rest-gw2/server/view.rb".freeze,
  "lib/rest-gw2/server/view/characters.erb".freeze,
  "lib/rest-gw2/server/view/check_list.erb".freeze,
  "lib/rest-gw2/server/view/check_percentage.erb".freeze,
  "lib/rest-gw2/server/view/commerce.erb".freeze,
  "lib/rest-gw2/server/view/dyes.erb".freeze,
  "lib/rest-gw2/server/view/error.erb".freeze,
  "lib/rest-gw2/server/view/exchange.erb".freeze,
  "lib/rest-gw2/server/view/guild_info.erb".freeze,
  "lib/rest-gw2/server/view/index.erb".freeze,
  "lib/rest-gw2/server/view/info.erb".freeze,
  "lib/rest-gw2/server/view/item_list.erb".freeze,
  "lib/rest-gw2/server/view/item_section.erb".freeze,
  "lib/rest-gw2/server/view/item_show.erb".freeze,
  "lib/rest-gw2/server/view/items.erb".freeze,
  "lib/rest-gw2/server/view/items_from.erb".freeze,
  "lib/rest-gw2/server/view/layout.erb".freeze,
  "lib/rest-gw2/server/view/members.erb".freeze,
  "lib/rest-gw2/server/view/menu.erb".freeze,
  "lib/rest-gw2/server/view/menu_armors.erb".freeze,
  "lib/rest-gw2/server/view/menu_commerce.erb".freeze,
  "lib/rest-gw2/server/view/menu_guild.erb".freeze,
  "lib/rest-gw2/server/view/menu_unlocks.erb".freeze,
  "lib/rest-gw2/server/view/menu_weapons.erb".freeze,
  "lib/rest-gw2/server/view/pages.erb".freeze,
  "lib/rest-gw2/server/view/profile.erb".freeze,
  "lib/rest-gw2/server/view/skins.erb".freeze,
  "lib/rest-gw2/server/view/stash.erb".freeze,
  "lib/rest-gw2/server/view/titles.erb".freeze,
  "lib/rest-gw2/server/view/unlock_percentage.erb".freeze,
  "lib/rest-gw2/server/view/unlocks_items.erb".freeze,
  "lib/rest-gw2/server/view/unlocks_list.erb".freeze,
  "lib/rest-gw2/server/view/wallet.erb".freeze,
  "lib/rest-gw2/server/view/wip.erb".freeze,
  "lib/rest-gw2/version.rb".freeze,
  "rest-gw2.gemspec".freeze,
  "task/README.md".freeze,
  "task/gemgem.rb".freeze]
  s.homepage = "https://github.com/godfat/rest-gw2".freeze
  s.licenses = ["Apache License 2.0".freeze]
  s.rubygems_version = "3.3.26".freeze
  s.summary = "A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rest-core>.freeze, [">= 4.0.0"])
    s.add_development_dependency(%q<jellyfish>.freeze, [">= 0"])
    s.add_development_dependency(%q<rack>.freeze, [">= 0"])
    s.add_development_dependency(%q<rackup>.freeze, [">= 0"])
    s.add_development_dependency(%q<rack-handlers>.freeze, [">= 0"])
    s.add_development_dependency(%q<dalli>.freeze, [">= 0"])
    s.add_development_dependency(%q<lru_redux>.freeze, [">= 0"])
  else
    s.add_dependency(%q<rest-core>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<jellyfish>.freeze, [">= 0"])
    s.add_dependency(%q<rack>.freeze, [">= 0"])
    s.add_dependency(%q<rackup>.freeze, [">= 0"])
    s.add_dependency(%q<rack-handlers>.freeze, [">= 0"])
    s.add_dependency(%q<dalli>.freeze, [">= 0"])
    s.add_dependency(%q<lru_redux>.freeze, [">= 0"])
  end
end
