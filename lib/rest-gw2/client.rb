# frozen_string_literal: true

require 'rest-core'
require 'rest-gw2/client/item_detail'
require 'set'

module RestGW2
  Client = RC::Builder.client do
    use RC::DefaultSite   , 'https://api.guildwars2.com/'
    use RC::DefaultHeaders, {'Accept' => 'application/json'}
    use RC::Oauth2Header  , 'Bearer', nil

    use RC::Timeout       , 30
    use RC::ErrorHandler  , lambda{ |env| RestGW2::Error.call(env) }
    use RC::ErrorDetectorHttp

    use RC::JsonResponse  , true
    use RC::CommonLogger  , nil
    use RC::Cache         , nil, 86400
  end

  class Error < RestCore::Error
    include RestCore

    class ServerError         < Error; end
    class ClientError         < Error; end

    class BadRequest          < ClientError; end
    class Unauthorized        < ClientError; end
    class Forbidden           < ClientError; end
    class NotFound            < ClientError; end

    class InternalServerError < ServerError; end
    class BadGateway          < ServerError; end
    class ServiceUnavailable  < ServerError; end

    attr_reader :error, :code, :url
    def initialize error, code, url=''
      @error, @code, @url = error, code, url
      super("[#{code}] #{error.inspect} from #{url}")
    end

    def self.call env
      error, code, url = env[RESPONSE_BODY], env[RESPONSE_STATUS],
                         env[REQUEST_URI]
      return new(error, code, url) unless error.kind_of?(Hash)
      case code
        when 400; BadRequest
        when 401; Unauthorized
        when 403; Forbidden
        when 404; NotFound
        when 500; InternalServerError
        when 502; BadGateway
        when 503; ServiceUnavailable
        else    ; self
      end.new(error, code, url)
    end
  end

  Client.include(Module.new{
    def me opts={}
      get('v2/account', {}, opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/account
    # https://wiki.guildwars2.com/wiki/API:2/worlds
    # https://wiki.guildwars2.com/wiki/API:2/guild/:id
    def account_with_detail opts={}
      m = me(opts)
      worlds = get('v2/worlds', :ids => m['world'])
      guilds = guilds_detail(m['guilds'])
      # m['guild_leader'] would be nil if there's no guild permission
      guild_leader = (m['guild_leader'] || []).map do |gid|
        guilds.find{ |g| g['id'] == gid }
      end
      me.merge(
        'world' => world_detail(worlds.first),
        'guilds' => guilds,
        'guild_leader' => guild_leader)
    end

    # https://wiki.guildwars2.com/wiki/API:2/guild/:id/stash
    def stash_with_detail gid, opts={}
      stash = get("v2/guild/#{gid}/stash")
      uids = stash.map{ |u| u['upgrade_id'] }.join(',')
      upgrades = get('v2/guild/upgrades', :ids => uids)
      bags = bags_with_detail(stash)

      upgrades.zip(bags).map do |(u, b)|
        u.merge('inventory' => b['inventory'])
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/guild/:id/treasury
    def treasury_with_detail gid, opts={}
      with_item_detail("v2/guild/#{gid}/treasury") do |items|
        items.map do |i|
          i.merge('id' => i['item_id'])
        end
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/guild/:id/members
    def guild_members gid, opts={}
      get("v2/guild/#{gid}/members", {}, opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/characters
    def get_character name, opts={}
      get("v2/characters/#{RC::Middleware.escape(name)}", {}, opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/characters
    def characters_with_detail opts={}
      chars = get('v2/characters', {}, opts).map do |name|
        get_character(name, opts)
      end

      guild_ids = chars.map{ |c| c['guild'] }.compact.uniq
      guild_promises = guilds_detail(guild_ids)

      title_ids = chars.map{ |c| c['title'] }.compact
      titles = get('v2/titles', :ids => title_ids.join(',')).
        group_by{ |t| t['id'] }

      guilds = guild_promises.group_by{ |g| g['id'] }

      chars.map do |c|
        c['guild'] = guilds.dig(c['guild'], 0)
        c['title'] = titles.dig(c['title'], 0, 'name')
        c
      end.sort_by{ |c| -c['age'] }
    end

    def bags_with_detail bags, opts={}
      detail = expand_item_detail(
        bags + bags.flat_map{ |c| c && c['inventory'] }, opts)
      detail.shift(bags.size).map do |b|
        b && b.merge('inventory' => detail.shift(b['size']))
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/currencies
    # https://wiki.guildwars2.com/wiki/API:2/account/wallet
    def wallet_with_detail opts={}
      wallet = get('v2/account/wallet', {}, opts)
      ids = wallet.map{ |w| w['id'] }.join(',')
      currencies = get('v2/currencies', :ids => ids).group_by{ |w| w['id'] }
      wallet.map do |currency|
        currency.merge(currencies[currency['id']].first)
      end.sort_by{ |c| c['order'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/account/skins
    def skins_with_detail opts={}
      unlocks_with_detail(:all_skins, 'v2/account/skins', opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/account/outfits
    def outfits_with_detail opts={}
      unlocks_with_detail(:all_outfits, 'v2/account/outfits', opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/account/mailcarriers
    def mailcarriers_with_detail opts={}
      unlocks_with_detail(:all_mailcarriers, 'v2/account/mailcarriers', opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/account/gliders
    def gliders_with_detail opts={}
      unlocks_with_detail(:all_gliders, 'v2/account/gliders', opts)
    end

    # https://wiki.guildwars2.com/wiki/API:2/skins
    # Returns Array[Promise[Detail]]
    def all_skins
      get('v2/skins').each_slice(100).map do |slice|
        get('v2/skins', :ids => slice.join(','))
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/outfits
    # Returns Array[Promise[Detail]]
    def all_outfits
      get('v2/outfits').each_slice(100).map do |slice|
        get('v2/outfits', :ids => slice.join(','))
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/mailcarriers
    # Returns Array[Promise[Detail]]
    def all_mailcarriers
      get('v2/mailcarriers').each_slice(100).map do |slice|
        get('v2/mailcarriers', :ids => slice.join(','))
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/gliders
    # Returns Array[Promise[Detail]]
    def all_gliders
      get('v2/gliders').each_slice(100).map do |slice|
        get('v2/gliders', :ids => slice.join(','))
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/colors
    # https://wiki.guildwars2.com/wiki/API:2/account/dyes
    def dyes_with_detail opts={}
      mine = get('v2/account/dyes', opts)
      get('v2/colors').each_slice(100).map do |slice|
        slice.join(',')
      end.map do |ids|
        with_item_detail('v2/colors', :ids => ids) do |colors|
          colors.map{ |c| c.merge('id' => c['item'], 'color_id' => c['id']) }
        end
      end.flatten.map do |color|
        color['count'] =
          if mine.include?(color['color_id'])
            1
          else
            0
          end
        color
      end.sort_by{ |c| c['categories'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/minis
    # https://wiki.guildwars2.com/wiki/API:2/account/minis
    def minis_with_detail opts={}
      mine = get('v2/account/minis', {}, opts)
      get('v2/minis').each_slice(100).map do |slice|
        slice.join(',')
      end.map do |ids|
        with_item_detail('v2/minis', :ids => ids) do |minis|
          minis.map{ |m| m.merge('id' => m['item_id'], 'mini_id' => m['id']) }
        end
      end.flatten.map do |mini|
        mini['count'] =
          if mine.include?(mini['mini_id'])
            1
          else
            0
          end
        mini['nolink'] = true
        mini
      end.sort_by{ |m| m['order'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/finishers
    # https://wiki.guildwars2.com/wiki/API:2/account/finishers
    def finishers_with_detail opts={}
      unlocked_promise = get('v2/account/finishers', {}, opts)

      all = get('v2/finishers').each_slice(100).map do |slice|
        slice.join(',')
      end.map do |ids|
        get('v2/finishers', :ids => ids)
      end

      mime = unlocked_promise.group_by{ |u| u['id'] }

      all.flatten.map do |finisher|
        finisher['count'] =
          if mime.dig(finisher['id'], 0, 'permanent')
            Float::INFINITY
          else
            mime.dig(finisher['id'], 0, 'quantity') || 0
          end
        finisher['nolink'] = true
        finisher['description'] = finisher['unlock_details']
        finisher
      end.sort_by{ |m| m['order'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/cats
    # https://wiki.guildwars2.com/wiki/API:2/account/home/cats
    def cats_with_detail opts={}
      unlocked_promise = get('v2/account/home/cats', opts)
      cat_details = get('v2/cats', :ids => get('v2/cats').join(','))
      unlocked = Set.new(unlocked_promise.map{ |cat| cat['id'] })

      cat_details.map do |cat|
        cat['count'] =
          if unlocked.member?(cat['id'])
            1
          else
            0
          end
        cat['name'] = cat['hint']
        cat
      end.sort_by{ |c| c['name'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/nodes
    # https://wiki.guildwars2.com/wiki/API:2/account/home/nodes
    def nodes_with_detail opts={}
      nodes = get('v2/nodes')
      unlocked = Set.new(get('v2/account/home/nodes', opts))

      nodes.map do |name|
        count =
          if unlocked.member?(name)
            1
          else
            0
          end
        {'name' => name, 'count' => count}
      end.sort_by{ |n| n['name'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/titles
    # https://wiki.guildwars2.com/wiki/API:2/account/titles
    def titles_with_detail opts={}
      get('v2/account/titles').each_slice(100).map do |slice|
        get('v2/titles', :ids => slice.join(','))
      end.flatten.sort_by{ |t| t['name'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/commerce/delivery
    def delivery_with_detail query={}, opts={}
      items = with_item_detail('v2/commerce/delivery',
                       {:page_size => 200}.merge(query), opts) do |delivery|
        ['price' => delivery['coins']] + delivery['items']
      end

      compact_items(items) do |last, current|
        last['id'] == current['id']
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/commerce/transactions
    def transactions_with_detail path, query={}, opts={}
      with_item_detail("v2/commerce/transactions/#{path}",
                       {:page_size => 200}.merge(query), opts) do |trans|
        trans.map do |t|
          t.merge('id' => t['item_id'], 'count' => t['quantity'])
        end
      end
    end

    def transactions_with_detail_compact path, query={}, opts={}
      items = transactions_with_detail(path, query, opts)

      compact_items(items) do |last, current|
        last['id'] == current['id'] && last['price'] == current['price']
      end
    end

    def with_item_detail path, query={}, opts={}, &block
      block ||= :itself.to_proc
      expand_item_detail(block.call(get(path, query, opts)), opts)
    end

    def expand_item_detail items, opts={}
      detail = ItemDetail.new(self, items, opts)
      detail.populate

      items.map(&detail.method(:fill))
    end

    private

    # https://wiki.guildwars2.com/wiki/API:2/worlds
    def world_detail world
      region = case r = world['id'] / 1000
               when 1
                 'North America'
               when 2
                 'Europe'
               else
                 "Unknown (#{r})"
               end
      lang   = case r = (world['id'] % 1000) / 100
               when 0
                 'English'
               when 1
                 'French'
               when 2
                 'German'
               when 3
                 'Spanish'
               else
                 "Unknown (#{r})"
               end
      "#{world['name']} (#{world['population']}) / #{region} (#{lang})"
    end

    def guilds_detail guilds
      guilds.map(&method(:get_guild))
    end

    # https://wiki.guildwars2.com/wiki/API:2/guild/:id
    def get_guild gid
      get("v2/guild/#{gid}")
    end

    def unlocks_with_detail kind, path, opts
      all = public_send(kind)
      mine = Set.new(get(path, {}, opts))
      all.flatten.map do |unlock|
        unlock['count'] =
          if mine.member?(unlock['id'])
            1
          else
            0
          end
        unlock['nolink'] = true
        unlock
      end.sort_by{ |u| u['order'] || u['name'] || '' }
    end

    def compact_items items
      items.inject([]) do |result, item|
        last = result.last

        if last && yield(last, item)
          last['count'] += item['count']
        else
          result << item
        end

        result
      end
    end
  })
end
