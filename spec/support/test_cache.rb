class TestCache < Hash
  attr_writer :max_key_length
  def max_key_length
    @max_key_length ||= 100
  end

  class KeyLengthError < ArgumentError; end

  attr_reader :last_accessed_key

  def get(key)
    @last_accessed_key = key
    check_key(key)
    self[key.to_s]
  end

  def set(key, val, opts={})
    @last_accessed_key = key
    check_key(key)
    self[key.to_s] = val
  end


private
  def check_key(key)
    if key.size > max_key_length
      raise KeyLengthError.new("key too long (#{key.size} > #{key.max_key_length}): #{key}")
    end
  end
end
