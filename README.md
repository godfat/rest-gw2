# rest-gw2 [![Build Status](https://secure.travis-ci.org/godfat/rest-gw2.png?branch=master)](http://travis-ci.org/godfat/rest-gw2) [![Coverage Status](https://coveralls.io/repos/godfat/rest-gw2/badge.png)](https://coveralls.io/r/godfat/rest-gw2) [![Join the chat at https://gitter.im/godfat/rest-gw2](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/godfat/rest-gw2)

by Lin Jen-Shin ([godfat](http://godfat.org))

## LINKS:

* [github](https://github.com/godfat/rest-gw2)
* [rubygems](https://rubygems.org/gems/rest-gw2)
* [rdoc](http://rdoc.info/github/godfat/rest-gw2)

## DESCRIPTION:

A very simple [Guild Wars 2 API](https://wiki.guildwars2.com/wiki/API:Main)
client built with [rest-core](https://github.com/godfat/rest-core).

There's also a bundled web application showing your items, serving as an
example using the client.

## FEATURES:

* Caching from rest-core for the win.
* Concurrency from rest-core for the win.

## REQUIREMENTS:

* Tested with MRI (official CRuby), Rubinius and JRuby.
* rest-core

### REQUIREMENTS: (if you need the web application)

* rack
* jellyfish
* dalli (optional for memcached)
* lru_redux (optional for LRU cache)

## INSTALLATION:

    gem install rest-gw2
    gem install rack jellyfish # (if you need the web application)

## SYNOPSIS:

``` ruby
require 'rest-gw2'
gw2 = RestGW2::Client.new(:access_token => '...')
gw2.get('account/bank') # => list of items in your bank
```

## Bundled Web Application:

If you would like to try it, run with:

    env RESTGW2_ACCESS_TOKEN=... rest-gw2

Or you could put your access token in a config file and point it with:

    env RESTGW2_CONFIG=... rest-gw2

The format for the config file would be like:

    RESTGW2_ACCESS_TOKEN=...
    RESTGW2_SECRET=...

The secret would be used for encrypting the access token. If you don't
set it then it would just use the default secret, which basically means
no encrypting at all, because the default secret is hard coded in the source,
which is publicly available because this is an open source project.

## CONTRIBUTORS:

* Lin Jen-Shin (@godfat)

## LICENSE:

Apache License 2.0

Copyright (c) 2015, Lin Jen-Shin (godfat)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
