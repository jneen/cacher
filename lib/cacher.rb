require 'digest/sha1'

require File.expand_path('cacher/version', File.dirname(__FILE__))

module Cacher
  extend self

  class Base
    include Cacher
  end

  #### configuration methods ####

  # sets "factory defaults"
  def self.reset!
    self.cache = nil
    self.namespace = false
    self.max_key_size = 250
    # default to false because Rails.cache handles marshalling by default
    self.marshal = false
    disable!

    self
  end

  def configure
    yield self
    self
  end

  def initialize(opts={}, &blk)
    opts.each do |k, v|
      send(:"#{k}=", v)
    end

    blk && configure(&blk)
  end

  ####
  # The backend cache.  The backend cache should must implement:
  #
  # #get (or #read)  - takes one argument and returns
  #                    something from a cache.
  # #set (or #write) - takes three arguments, a key, a value, and
  #                    an options hash, and sets something in a cache.
  attr_writer :cache
  def cache
    return @cache if instance_variable_defined? :@cache

    Cacher.cache ||= if defined?(::Rails) and ::Rails.respond_to? :cache
      Rails.cache
    elsif defined?(::RAILS_CACHE)
      RAILS_CACHE
    else
      raise ArgumentError.new <<-msg.strip
        please define a cache backend for Cacher.
      msg
    end

    @cache = Cacher.cache
  end

  attr_writer :namespace
  def namespace
    return @namespace if instance_variable_defined? :@namespace
    @namespace = Cacher.namespace
  end

  def namespaced?
    !!namespace
  end

  attr_writer :max_key_size
  def max_key_size
    @max_key_size ||= Cacher.max_key_size
  end

  attr_writer :marshal
  def marshal?
    return @marshal if instance_variable_defined? :@marshal
    @marshal = Cacher.marshal?
  end

  attr_writer :enabled
  def enable!
    @enabled = true
  end

  def disable!
    @enabled = false
  end

  def bust!
    bust_hash[object_id] = true
    if block_given?
      begin
        yield
      ensure
        unbust!
      end
    end
  end

  def unbust!
    bust_hash[object_id] = false
  end

  def busting?
    !!bust_hash[object_id]
  end

private
  def bust_hash
    Thread.current[:cacher_bust_hash] ||= {}
  end
public

  def enabled?
    return @enabled if instance_variable_defined? :@enabled
    @enabled = Cacher.enabled?
  end

  # set up Cacher with the defaults
  reset!

  ##################
  #### core api ####
  ##################
  def key?(key)
    return false unless enabled?

    !!cache_get(key)
  end

  def get(key, options={}, &blk)
    return set(key, options, &blk) if options.delete(:break) || busting?

    cached = cache_get(key)

    if cached.nil?
      return blk && set(key, options, &blk)
    end

    unmarshal_value(cached)
  end

  def get_multi(keys)
    prepared_keys = keys.map { |k| prepare_key(k) }
    cached = cache.read_multi(*prepared_keys)
    cached_results = cached.inject({}) do |results, (key, value)|
      results[key] = unmarshal_value(value)
      results
    end

    keys.map { |key| cached_results[prepare_key(key)] }
  end

  def set(key, options={}, &blk)
    val = do_block(&blk)
    cache_set(key, marshal_value(val), options)
    val
  end

private
  def decorate_key(key)
    if namespaced?
      key = "#{namespace}/#{key}"
    end

    key += "/marshal" if marshal?

    key
  end

  def prepare_key(key)
    decorated = decorate_key(key)

    if decorated.size > max_key_size
      decorated = decorate_key("sha1/#{Digest::SHA1.hexdigest(key)}")
    end

    decorated
  end

  def cache_get(key)
    return nil unless enabled?

    key = prepare_key(key)

    if cache.respond_to? :get
      cache.get(key)
    else
      cache.read(key)
    end
  end

  def cache_set(key, val, options={})
    return val unless enabled?

    key = prepare_key(key)

    if cache.respond_to? :set
      cache.set(key, val, options)
    else
      cache.write(key, val, options)
    end

    val
  end

  def do_block(&block)
    if block.arity > 0
      response = {}
      block.call(response)
      response
    else
      block.call
    end
  end

  CACHER_NIL = 'cacher/nil'
  def marshal_value(val)
    if marshal?
      Marshal.dump(val)
    else
      return CACHER_NIL if val.nil?
      val
    end
  end

  def unmarshal_value(val)
    if marshal?
      safe_marshal_load(val)
    else
      return nil if val == CACHER_NIL
      val
    end
  end

  def safe_marshal_load(val)
    Marshal.load(val)
  rescue ArgumentError => e
    last_try ||= nil
    if e.message =~ /^undefined class\/module (.+?)$/
      const_name = $1
      raise e if last_try == const_name
      const_name.respond_to?(:constantize) ? const_name.constantize : const_lookup(const_name)
      last_try = const_name
      retry
    else
      raise e
    end
  end

  def const_lookup(const_name)
    constant = Object
    const_name.split('::').each do |name|
      constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
    end
  end
end
