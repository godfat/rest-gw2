
require 'rest-core'

require 'time'
require 'erb'
require 'cgi'

module RestGW2
  class View < Struct.new(:request, :query_t)
    HTML = Class.new(Struct.new(:to_s))
    COINS = %w[gold silver copper].zip(%w[
      https://wiki.guildwars2.com/images/d/d1/Gold_coin.png
      https://wiki.guildwars2.com/images/3/3c/Silver_coin.png
      https://wiki.guildwars2.com/images/e/eb/Copper_coin.png
    ]).freeze

    def render name, arg=nil
      erb(:layout){ erb(name, arg) }
    end

    # FIXME: controller shouldn't call this directly
    def sum_trans trans
      trans.inject(0) do |sum, t|
        sum + t['price'] * t['quantity']
      end
    end

    # FIXME: controller shouldn't call this directly
    def sum_items items
      items.inject([0, 0]) do |sum, i|
        next sum unless i
        b = i['buys']
        s = i['sells']
        sum[0] += b['unit_price'] * i['count'] if b
        sum[1] += s['unit_price'] * i['count'] if s
        sum
      end
    end

    # FIXME: controller shouldn't call this directly
    def show_guild g
      HTML.new(menu("/guilds/#{g['guild_id']}",
                    h("#{g['guild_name']} [#{g['tag']}]")))
    end

    # FIXME: controller shouldn't call this directly
    def query_p
      @query_p ||= zero_is_nil(request.GET['p'])
    end

    private
    def erb name, arg=nil, &block
      ERB.new(views(name)).result(binding, &block)
    end

    def h str
      case str
      when String
        CGI.escape_html(str)
      when HTML
        str.to_s
      end
    end

    def u str
      CGI.escape(str) if str.kind_of?(String)
    end

    def path str, q={}
      RC::Middleware.request_uri(
        RC::REQUEST_PATH => "#{ENV['RESTGW2_PREFIX']}#{str}",
        RC::REQUEST_QUERY => q)
    end

    def views name
      File.read("#{__dir__}/view/#{name}.erb")
    end

    def refresh_path
      path(request.path, :p => query_p, :r => '1', :t => query_t)
    end

    # TODO: clean me up
    def menu item, title, query={}
      href = path(item, query.merge(:t => query_t))
      if path(request.path, :p => query_p, :t => query_t) == href
        title
      else
        %Q{<a href="#{href}">#{title}</a>}
      end
    end

    # TODO: clean me up
    def menu_sub prefix, item, title
      key = "#{prefix}#{item}"
      if path(request.path) == path(key)
        menu(key, title, :p => query_p)
      else
        menu(key, title)
      end
    end

    def menu_guild gid, item, title
      menu("/guilds/#{gid}#{item}", title)
    end

    def menu_char name
      menu("/characters/#{RC::Middleware.escape(name)}", name)
    end

    def menu_item item, title
      menu_sub('/items', item, title)
    end

    def menu_skin item, title
      menu_sub('/skins', item, title)
    end

    def menu_trans item, title
      menu_sub('/transactions', item, title)
    end

    def page num
      menu(request.path, num.to_s, :p => zero_is_nil(num))
    end

    # HELPER
    def blank_icon
      %Q{<img class="icon" alt="blank" src="https://upload.wikimedia.org/wikipedia/commons/d/d2/Blank.png"/>}
    end

    def item_wiki_list items
      items.map(&method(:item_wiki)).join("\n")
    end

    def item_wiki item
      if item['name'] && item['icon']
        name = item['name'].tr(' ', '_')
        img = %Q{<img class="#{item_class(item)}"} +
              %Q{ alt="#{item_name(item)}"} +
              %Q{ title="#{item_title(item)}"} +
              %Q{ src="#{h item['icon']}"/>}
        %Q{<a href="http://wiki.guildwars2.com/wiki/#{u name}">#{img}</a>}
      else
        blank_icon
      end
    end

    def item_link item
      name = item_name(item)
      if item['nolink']
        name
      else
        menu("/items/#{item['id']}", name)
      end
    end

    def item_name item
      h(item['name'] || "?#{item['id']}?")
    end

    def item_title item
      d = item['description']
      d && d.unpack('U*').map{ |c| "&##{c};" }.join
    end

    def item_count item
      c = item['count']
      "(#{c})" if c > 1
    end

    def item_price item
      b = item['buys']
      s = item['sells']
      bb = b && price(b['unit_price'])
      ss = s && price(s['unit_price'])
      %Q{#{bb} / #{ss}} if bb || ss
    end

    def item_class item
      missing = if item['count'] == 0 then ' missing' end
      rarity = if item['rarity']
        " rarity rarity-#{item['rarity'].downcase}"
      end
      "icon#{rarity}#{missing}"
    end

    def price copper
      g = copper / 100_00
      s = copper % 100_00 / 100
      c = copper % 100
      l = [g, s, c]
      n = l.index(&:nonzero?)
      return '-' unless n
      l.zip(COINS).drop(n).map do |(num, (name, src))|
        %Q{#{num}<img class="price"} +
        %Q{ alt="#{name}" title="#{name}" src="#{src}"/>}
      end.join(' ')
    end

    def dye_color dye
      %w[cloth leather metal].map do |kind|
        rgb = dye[kind]['rgb']
        rgb && dye_preview(kind, rgb.join(', '))
      end.join("\n")
    end

    def dye_preview kind, rgb
      %Q{<span class="icon" title="#{kind}, rgb(#{rgb})"} +
           %Q{ style="background-color: rgb(#{rgb})"></span>}
    end

    def abbr_time_ago time, precision=1
      return unless time
      ago = time_ago(time)
      short = ago.take(precision).join(' ')
      %Q{(<abbr title="#{time}, #{ago.join(' ')} ago">#{short} ago</abbr>)}
    end

    def time_ago time
      duration((Time.now - Time.parse(time)).to_i)
    end

    def duration delta
      result = []

      [[ 60, :seconds],
       [ 60, :minutes],
       [ 24, :hours  ],
       [365, :days   ],
       [999, :years  ]].
        inject(delta) do |length, (divisor, name)|
          quotient, remainder = length.divmod(divisor)
          result.unshift("#{remainder} #{name}")
          break if quotient == 0
          quotient
        end

      result
    end

    def plural objects, name
      size = objects.size
      if size > 1
        "#{size} #{name}s"
      else
        "#{size} #{name}"
      end
    end

    def zero_is_nil n
      r = n.to_i
      r if r != 0
    end
  end
end
