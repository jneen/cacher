describe Cacher do
  let(:cache) { TestCache.new }
  let(:cacher) { Cacher::Base.new(:cache => cache) }

  describe 'enabled' do
    before do
      cacher.enable!
    end

    it 'sets and gets key' do
      assert { cacher.get('foo').nil? }
      assert { cacher.set('foo') { 'bar' } == 'bar' }
      assert { cacher.get('foo') == 'bar' }
    end

    it 'gets with block syntax' do
      assert { cacher.get('foo') { 1 } == 1 }
      assert { cacher.get('foo') { 2 } == 1 }
    end

    it 'only calls the block once' do
      counter = 0

      10.times do
        cacher.get('foo') { counter += 1 }
      end

      assert { counter == 1 }
    end

    it 'queries a key with #key?' do
      assert { cacher.key?('foo') == false }
      cacher.set('foo') { 'bar' }
      assert { cacher.key?('foo') == true }
    end

    it 'transparently handles nil values' do
      cacher.set('foo') { nil }
      assert { cacher.key?('foo') == true }
      assert { cacher.get('foo') == nil }
      assert { cacher.get('foo') { :not_nil } == nil }
    end

    it 'uses a namespace' do
      cacher.namespace = 'my_cool_namespace'
      cacher.set('foo') { 1 }
      assert { cache.keys.include? 'my_cool_namespace/foo' }
      deny   { cache.keys.include? 'foo' }
    end

    it %[doesn't use a namespace by default] do
      deny { cacher.namespaced? }
      cacher.set('foo') { 1 }
      assert { cache.keys.include? 'foo' }
    end

    it %[shortens a key if it's too long] do
      key = "a_really_long_key/" * 100
      cacher.max_key_size = 100

      cacher.set(key) { 3 }
      assert { cache.keys.first =~ %r[^sha1/[0-9a-f]+$] }
      assert { cacher.get(key) == 3 }
    end
  end

  describe 'disabled' do
    before do
      cacher.disable!
    end

    it 'nops when setting a key' do
      assert { cacher.get('foo').nil? }
      assert { cacher.set('foo') { 'bar' } == 'bar' }
      assert { cacher.get('foo').nil? }
    end
  end
end
