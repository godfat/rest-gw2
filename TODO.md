# Test

* Write a Rack app crawler and visit all the pages, and save the responses
  and the cache data from the client. We could have a test to restore the
  cache data for the client, and then visit all the pages again, and compare
  the saved responses and the new responses. They should be identical for
  all (200 OK) pages, of course.

# View

* Put upgrades and infusions icons in a column, rather than a row.
* Show upgrades and infusions names and prices.

# Feature

* https://wiki.guildwars2.com/wiki/API:2/account/finishers
* https://wiki.guildwars2.com/wiki/API:2/account/gliders
* https://wiki.guildwars2.com/wiki/API:2/account/home/cats
* https://wiki.guildwars2.com/wiki/API:2/account/home/nodes
* https://wiki.guildwars2.com/wiki/API:2/account/mailcarriers
* https://wiki.guildwars2.com/wiki/API:2/account/outfits
* https://wiki.guildwars2.com/wiki/API:2/commerce/delivery
* https://wiki.guildwars2.com/wiki/API:2/commerce/exchange
* https://wiki.guildwars2.com/wiki/API:2/commerce/listings

# Code Clarity

* Use more classes and objects so that the types are more clear
* Split actions and utility methods

# Performance

* Smart item details cache, basing on item id
