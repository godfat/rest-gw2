# CHANGES

## rest-gw2 0.5.0 -- 2018-12-26

* Bunch of performance improvement.
* Allow setting `ENV['GW2_POOL_SIZE']` to configure pool size.
* Added `RestGW2::Client#me`
* Added `RestGW2::Client#guild_members`
* Added `RestGW2::Client#outfits_with_detail`
* Added `RestGW2::Client#mailcarriers_with_detail`
* Added `RestGW2::Client#gliders_with_detail`
* Added `RestGW2::Client#all_outfits`
* Added `RestGW2::Client#all_mailcarriers`
* Added `RestGW2::Client#all_gliders`
* Added `RestGW2::Client#all_fininshers`
* Added `RestGW2::Client#all_cats`
* Added `RestGW2::Client#all_titles`
* Added `RestGW2::Client#finishers_with_detail`
* Added `RestGW2::Client#cats_with_detail`
* Added `RestGW2::Client#nodes_with_detail`
* Added `RestGW2::Client#titles_with_detail`
* Added `RestGW2::Client#delivery_with_detail`
* Added `RestGW2::Client#all_unlocks`
* Added `RestGW2::Client#unlocks_with_detail`
* Added `RestGW2::ItemDetail`
* Show guild_leader for account_with_detail
* Added a bunch of different unlocks pages
* Added exchange rate page
* Show favicon based on the access token
* Show rarity border for items
* Show total prices for a particular item

## rest-gw2 0.4.0 -- 2016-02-05

* Added `RestGW2::Client#stash_with_detail`
* Added `RestGW2::Client#treasury_with_detail`
* Added `RestGW2::Client#get_character`
* Added `RestGW2::Client#characters_with_detail`
* Added `RestGW2::Client#bags_with_detail`
* Added `RestGW2::Client#dyes_with_detail`
* Added `RestGW2::Client#skins_with_detail`
* Added `RestGW2::Client#all_skins`
* Added `RestGW2::Client#minis_with_detail`
* Added `RestGW2::Client#expand_item_detail`
* Added a bunch of new pages for the server.

## rest-gw2 0.2.0 -- 2015-12-18

### RestGW2::Client

* Changed default site so that it doesn't contain `v2`.
* Changed default timeout from 10 seconds to 30 seconds.
* Changed default cache from 10 minutes to 1 day.
* Now we have `RestGW2::Error` instead of `RuntimeError`.
* Added `RestGW2::Client#account_with_detail`
* Added `RestGW2::Client#wallet_with_detail`
* Added `RestGW2::Client#transactions_with_detail`
* Added `RestGW2::Client#transactions_with_detail_compact`
* Now `with_item_detail` would also return commerce data.
* Now `with_item_detail` would fetch 100 items in a request.
* Now `with_item_detail` could take a query and option.

### RestGW2::Server

* Added a command line tool `rest-gw2` for launching the bundled server.
* Many stuffs are implemented now.
* Pages are much more beautiful now.
* We could also use lru_redux for caching, other than memcached.

## rest-gw2 0.1.0 -- 2015-11-14

* Birthday!
