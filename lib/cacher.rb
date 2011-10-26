require 'digest/sha1'

require File.expand_path('cacher/version', File.dirname(__FILE__))

module Cacher
  extend self

  class Base
    include Cacher
  end

  #### configuration methods ####
  attr_reader :options
  def initialize(opts={})
    opts.each do |k, v|
      send(:"#{k}=", v)
    end
  end

  attr_writer :cache
  def cache
    @cache ||= Rails.cache
  end

  attr_accessor :namespace
  def namespaced?
    !!namespace
  end

  attr_writer :max_key_size
  def max_key_size
    @max_key_size ||= 100
  end

  attr_writer :marshal
  def marshal?
    return @marshal if instance_variable_defined? :@marshal

    # default to false because Rails.cache handles marshalling for us
    @marshal = false
  end

  def enabled?
    return @enabled if instance_variable_defined? :@enabled
    @enabled = false
  end

  def enable!
    @enabled = true
  end

  def disable!
    @enabled = false
  end

  #### core api ####
  def key?(key)
    return false unless enabled?

    !!cache_get(key)
  end

  def get(key, options={}, &blk)
    return set(key, options, &blk) if options.delete(:break)

    cached = cache_get(key)

    if cached.nil?
      return blk && set(key, options, &blk)
    end

    unmarshal_value(cached)
  end

  def set(key, options={}, &blk)
    val = do_block(&blk)
    cache_set(key, marshal_value(val))
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

  def cache_set(key, val)
    return val unless enabled?

    key = prepare_key(key)

    if cache.respond_to? :set
      cache.set(key, val)
    else
      cache.write(key, val)
    end

    val
  end

  def do_block(&block)
    return nil unless block_given?

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
      Marshal.load(val)
    else
      return nil if val == CACHER_NIL
      val
    end
  end
end
