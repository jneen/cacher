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
    raise KeyLengthError if key.size > max_key_length
  end
end
