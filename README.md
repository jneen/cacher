# Cacher

Cacher is a human interface to an underlying cache.

# Usage

``` ruby
backend = Dalli::Client.new(...)
# or Rails.cache, etc.

Cacher.cache = Rails.cache # or Dalli::Client.new(...)
                           # as long as it responds to
                           # set/get or read/write, you're good

# standard get-or-calculate method
Cacher.get("some_key") { expensive_calculation }

# test the presence of a key
Cacher.key?("some_key")

# or alternately, for more data
Cacher.get "some_key" do |res|
  res[:foo] = 'bar'
  res[:baz] = 'quux'
end  # => { foo: 'bar', baz: 'quux' }

# same semantics as get, but always calculates
Cacher.set("some_key") { some_val }

Cacher.bust! do
  # in this block (and in this thread), calls to Cacher.get with a block
  # won't read the cache, but will instead calculate the block and write
  # it back, returning the calculated result.
end
```

## Why use Cacher?

Cacher handles the following for you:

* Transparently handles the difference between setting a key to nil and the key not being set
* Optional namespacing
* Optional marshalling with `Marshal`
* Automatically uses the SHA1 of a key if it's over a particular length
* makes it easy to switch caching on or off in different environments
* makes it easy to bust through the cache in particular situations (see `Cacher.bust`)

# Configuration

``` ruby
Cacher.configure do |config|
  # set the backend cache.  It should respond to get/set, or read/write
  # (thank you Rails.cache).
  config.cache = Dalli::Client.new(...)

  # if disabled, Cacher will always run the given block on #get
  config.enable!
  config.disable!

  # set up a namespace - use `false` to disable namespacing
  # namespacing is off by default
  config.namespace = "my_namespace"

  # configure a maximum key size (default 250)
  config.max_key_size = 250

  # toggle marshalling on/off.  It should be turned off if the backend
  # cache handles marshalling for you, like Rails.cache.
  config.marshal = false

  # always bust through the cache
  config.bust!
end
```
