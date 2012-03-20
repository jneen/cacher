describe Cacher do
  describe 'configuring' do
    it 'sets global configuration options' do
      deny { Cacher::Base.new.namespaced? }
      Cacher.namespace = 'global'
      assert { Cacher::Base.new.namespaced? }
      assert { Cacher::Base.new.namespace == 'global' }
    end

    it 'yields a configure block' do
      some_cache = TestCache.new
      Cacher.configure do |config|
        config.cache = some_cache
      end

      assert { Cacher.cache.object_id == some_cache.object_id }
    end

    it 'yields a configure block on a new object' do
      my_cacher = Cacher::Base.new do |cacher|
        cacher.max_key_size = 12
      end

      assert { my_cacher.max_key_size == 12 }
    end

    it 'creates a new object with a hash' do
      my_cacher = Cacher::Base.new(:enabled => true)
      assert { my_cacher.enabled? }
    end
  end

  describe 'usage' do
    let(:cache) { TestCache.new }
    let(:cacher) { Cacher::Base.new(:cache => cache) }

    after do
      Cacher.reset!
    end

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
        assert { cache.last_accessed_key =~ %r[^sha1/[0-9a-f]+$] }
        assert { cacher.get(key) == 3 }
      end

      describe 'marshalling' do
        before do
          cacher.marshal = true
        end

        it 'adds /marshal to the end of the key' do
          cacher.set('foo') { 1 }

          assert { cache.last_accessed_key == 'foo/marshal' }
        end

        it 'marshals the value' do
          cacher.set('foo') { 1 }

          assert { cache[cache.last_accessed_key] == Marshal.dump(1) }
        end

        it 'gets the marshalled value back' do
          cacher.set('foo') { 1 }

          assert { cacher.get('foo') == 1 }
        end

        it 'attempts to find missing constants' do
          module Finders
            class Keepers; end

            def self.const_missing(name)
              class_eval "class #{name}; end"
            end
          end

          cacher.set('keepers') { Finders::Keepers.new }
          assert { cacher.get('keepers').is_a? Finders::Keepers }
          Finders.send :remove_const, 'Keepers'
          assert { cacher.get('keepers').is_a? Finders::Keepers }
          Object.send :remove_const, 'Finders'
          assert { rescuing { cacher.get('keepers') }.is_a? NameError }
        end
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

    describe 'busting the cache' do
      before do
        cacher.enable!
      end

      it 'writes through when busting' do
        cacher.set('foo') { 1 }

        cacher.bust!
        cacher.get('foo') { 2 }
        cacher.unbust!

        assert { cacher.get('foo') == 2 }
      end

      it 'busts with a block' do
        cacher.set('foo') { 1 }

        cacher.bust! do
          cacher.get('foo') { 2 }
        end

        assert { cacher.get('foo') == 2 }
      end
    end
  end
end
