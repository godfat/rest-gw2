
module RestGW2
  ItemDetailStruct ||= Struct.new(:client, :raw, :opts)

  class ItemDetail < ItemDetailStruct
    attr_reader :detail, :upgrades, :stats, :skins

    def populate
      detail_promises = item_detail_group_by_id(raw)
      upgrades_promises = extract_items_in_slots('upgrades', 'infusions')
      stats_promises = [expand_stats_detail]

      @detail = detail_promises_to_map(detail_promises)
      @upgrades = detail_promises_to_map(upgrades_promises)
      @stats = detail_promises_to_map(stats_promises)
      @skins = client.all_skins.flatten.group_by{ |s| s['id'] }
    end

    def fill item
      return item unless data = (item && detail[item['id']])

      s = item['skin']
      u = item['upgrades']
      f = item['infusions']
      t = item['stats']

      item.merge(data).merge(
        'count' => item['count'] || 1,
        'skin' => s && skins[s].first,
        'upgrades' => u && u.flat_map(&upgrades.method(:[])),
        'infusions' => f && f.flat_map(&upgrades.method(:[])),
        'stats' => t && stats[t['id']].merge(t))
    end

    private

    # Returns Array[Promise[Array[Detail]]]
    # https://wiki.guildwars2.com/wiki/API:2/items
    # https://wiki.guildwars2.com/wiki/API:2/commerce/prices
    def item_detail_group_by_id items
      items.map{ |i| i && i['id'] }.compact.each_slice(100).map do |slice|
        q = {:ids => slice.join(',')}
        [client.get('v2/items', q),
         client.get('v2/commerce/prices', q,
           {:error_detector => false}.merge(opts))]
      end
    end

    # Returns Array[Promise[Array[Detail]]]
    def extract_items_in_slots *slots
      items = raw.flat_map do |i|
        if i
          i.values_at(*slots).flatten.compact.map do |id|
            {'id' => id}
          end
        else
          []
        end
      end
      item_detail_group_by_id(items)
    end

    # https://wiki.guildwars2.com/wiki/API:2/itemstats
    def expand_stats_detail
      raw.map{ |i| i && i.dig('stats', 'id') }.
        compact.uniq.each_slice(100).map do |ids|
          client.get('v2/itemstats', :ids => ids.join(','))
        end
    end

    # this is probably a dirty way to workaround converting hashes to arrays
    def detail_promises_to_map promises
      promises.flat_map(&:itself).map(&:to_a).flatten.group_by{ |i| i['id'] }.
        inject({}){ |r, (id, v)| r[id] = v.inject(&:merge); r }
    end
  end
end
