# frozen_string_literal: true

require 'rest-gw2/server/imp'

module RestGW2
  class ServerAction
    def self.weapons
      %w[Greatsword Sword Hammer Mace Axe Dagger
         Staff Scepter
         Longbow Shortbow Rifle Pistol
         Shield Torch Focus Warhorn
         Spear Speargun Trident]
    end

    def self.armors
      %w[Helm Shoulders Coat Gloves Leggings Boots HelmAquatic]
    end

    def self.armors_weight
      %w[Light Medium Heavy Clothing]
    end

    def self.crafting
      %w[Weaponsmith Huntsman Artificer
         Armorsmith Leatherworker Tailor
         Jeweler Chef Scribe]
    end

    include Jellyfish
    controller_include NormalizedPath, ServerImp

    handle Timeout::Error do
      status 504
      render :error, 'Timeout. Please try again.'
    end

    handle RestGW2::Error do |e|
      status 502
      render :error, e.error['text']
    end

    post '/access_token' do
      t = encrypt(request.POST['access_token'])
      r = request.POST['referrer']
      u = if r == view.path('/') then view.path('/account') else r end
      found "#{u}?t=#{t}"
    end

    get '/' do
      render :index
    end

    get '/account' do
      info = gw2_request(:account_with_detail).dup
      %w[guilds guild_leader].each do |guild|
        info[guild] = info[guild].map(&view.method(:show_guild))
      end

      render :info, info
    end

    get %r{\A/guilds/(?<uuid>[^/]+)\z} do |m|
      guild_request(m[:uuid]) do |arg|
        render :guild_info, arg.merge(:guild => arg.dig(:guilds, arg[:gid]))
      end
    end

    get %r{\A/guilds/(?<uuid>[^/]+)/members\z} do |m|
      guild_request(m[:uuid]) do |arg|
        members = gw2_defer(:guild_members, arg[:gid])

        render :members, arg.merge(:members => members)
      end
    end

    get %r{\A/guilds/(?<uuid>[^/]+)/items\z} do |m|
      guild_request(m[:uuid]) do |arg|
        stash    = gw2_defer(   :stash_with_detail, arg[:gid])
        treasury = gw2_defer(:treasury_with_detail, arg[:gid])

        render :stash, arg.merge(:stash => stash, :treasury => treasury)
      end
    end

    get '/characters' do
      chars = gw2_request(:characters_with_detail)
      total = chars.inject(0){ |t, c| t + c['age'] }
      craftings = group_by_crafting(chars)

      render :characters, :chars => chars, :total => total,
                          :craftings => craftings
    end

    get %r{\A/characters/(?<name>[\w ]+)\z} do |m|
      characters = gw2_request(:characters_with_detail)
      names = characters.map { |c| c['name'] }
      name  = m[:name]
      char  = characters.find{ |c| c['name'] == name }
      equi  = gw2_defer(:expand_item_detail, char['equipment'])
      bags  = gw2_defer(:bags_with_detail  , char['bags'])

      equi_buy, equi_sell = view.sum_items(equi)
      bags_buy, bags_sell = view.sum_items(bags +
                              bags.flat_map{ |c| c && c['inventory'] })

      render :profile, :names => names, :equi => equi, :bags => bags,
                       :equi_buy => equi_buy, :equi_sell => equi_sell,
                       :bags_buy => bags_buy, :bags_sell => bags_sell
    end

    get '/items' do
      render :items, gw2_request(:with_item_detail, 'v2/account/inventory')
    end

    get '/items/bank' do
      render :items, gw2_request(:with_item_detail, 'v2/account/bank')
    end

    get '/items/materials' do
      render :items, gw2_request(:with_item_detail, 'v2/account/materials')
    end

    get '/items/all' do
      render :items, all_items
    end

    get %r{\A/items/(?<id>\d+)\z} do |m|
      acct, bank, materials, chars = find_my_item(m[:id].to_i)
      buy, sell = view.sum_items(acct + bank + materials +
                                 chars.values.flatten)

      render :items_from, :acct => acct, :bank => bank,
                          :materials => materials, :chars => chars,
                          :buy => buy, :sell => sell
    end

    get '/wallet' do
      render :wallet, gw2_request(:wallet_with_detail)
    end

    get '/unlocks/skins/backpacks' do
      skin_request('Back')
    end

    weapons.each do |weapon|
      get "/unlocks/skins/weapons/#{weapon.downcase}" do
        skin_request('Weapon', weapon)
      end
    end

    get '/unlocks/skins/weapons/other' do
      subtype = Regexp.new("\\A(?:#{Regexp.union(*ServerAction.weapons)})\\z")

      skin_request('Weapon', 'Other') do |item|
        item.dig('details', 'type') !~ subtype
      end
    end

    armors.each do |armor|
      armors_weight.each do |weight|
        get "/unlocks/skins/armors/#{armor.downcase}/#{weight.downcase}" do
          skin_request('Armor', armor, weight)
        end
      end
    end

    get '/unlocks/skins/armors/other' do
      subtype = Regexp.new("\\A(?:#{Regexp.union(*ServerAction.armors)})\\z")

      skin_request('Armor', 'Other') do |item|
        item.dig('details', 'type') !~ subtype
      end
    end

    get '/unlocks/skins/gathering' do
      skin_request('Gathering')
    end

    get '/unlocks/dyes' do
      dyes = gw2_request(:dyes_with_detail)
      buy, sell = view.sum_items(dyes)
      unlocked = dyes.count{ |d| d['count'] > 0 }

      render :dyes, :dyes => dyes,
                    :buy => buy, :sell => sell,
                    :unlocked => unlocked
    end

    get '/unlocks/minis' do
      render :minis, gw2_request(:minis_with_detail)
    end

    get '/unlocks/cats' do
      cats = gw2_request(:cats_with_detail)
      unlocked = cats.count{ |c| c['unlocked'] }

      render :cats, :cats => cats, :unlocked => unlocked
    end

    get '/achievements/titles' do
      render :titles, gw2_request(:titles_with_detail)
    end

    get '/commerce/delivery' do
      items = gw2_request(:delivery_with_detail, :page => view.query_p)
      total = items.shift['price']

      render :commerce, :items => items, :total => total
    end

    get '/commerce/buying' do
      trans_request(:transactions_with_detail_compact, 'current/buys')
    end

    get '/commerce/selling' do
      trans_request(:transactions_with_detail_compact, 'current/sells')
    end

    get '/commerce/bought' do
      trans_request(:transactions_with_detail_compact, 'history/buys')
    end

    get '/commerce/sold' do
      trans_request(:transactions_with_detail_compact, 'history/sells')
    end

    get '/exchange' do
      # We try to spend 800 gems to buy golds as the standard for buying gold,
      # and try to spend 100 golds to buy gems as the standard for buying gems
      # Then we try to use those ratios to calculate the prices and match
      # the information in the game. We also try to include the standard
      # to the list, sorted it to the proper place.
      # This is trying to match whatever the game is showing, and also show
      # the real responses from the API.
      gold_std, gem_std =
        [stub_gold(800), stub_gem(100_00_00)].map(&method(:resolve_count))

      buy_gold_coins_per_gem = gold_std['coins_per_gem']
      buy_gold = [gold_std, 1, 10, 50, 100, 250].map do |gold|
        case gold
        when Numeric
          coins = gold * 100_00
          stub_gold((coins.to_f / buy_gold_coins_per_gem).round, coins)
        else
          gold
        end
      end.sort_by{ |g| g['count'] }

      buy_gem_coins_per_gem = gem_std['coins_per_gem']
      buy_gem = [gem_std, 400, 800, 1200, 2000].map do |gem|
        case gem
        when Numeric
          stub_gem(gem * buy_gem_coins_per_gem, gem)
        else
          gem
        end
      end.sort_by{ |g| g['count'] }

      render :exchange, :buy_gold => buy_gold, :buy_gem => buy_gem
    end

    get '/tokeninfo' do
      render :info, gw2_request(:get, 'v2/tokeninfo')
    end
  end
end
