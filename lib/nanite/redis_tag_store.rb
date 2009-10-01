require 'redis'

module Nanite

  # Implementation of a tag store on top of Redis
  # For a nanite with the identity 'nanite-foobar', we store the following:
  #
  # s-nanite-foobar: { /foo/bar, /foo/nik } # a SET of the provided services
  # tg-nanite-foobar: { foo-42, customer-12 } # a SET of the tags for this agent
  #
  # Also we do an inverted index for quick lookup of agents providing a certain
  # service, so for each service the agent provides, we add the nanite to a SET
  # of all the nanites that provide said service:
  #
  # foo/bar: { nanite-foobar, nanite-nickelbag, nanite-another } # redis SET
  #
  # We do that same thing for tags:
  #
  # some-tag: { nanite-foobar, nanite-nickelbag, nanite-another } # redis SET
  #
  # This way we can do a lookup of what nanites provide a set of services and tags based
  # on redis SET intersection:
  #
  # nanites_for('/gems/list', 'some-tag')
  # => returns an array of nanites that provide the intersection of these two service tags

  class RedisTagStore

    # Initialize tag store with given redis handle
    def initialize(redis)
      @redis = redis
    end

    # Store services and tags for given agent
    def store(nanite, services, tags)
      store_elems(nanite, "s-#{nanite}", 'naniteservices', services)
      store_elems(nanite, "tg-#{nanite}", 'nanitestags', tags)
    end

    # Delete services and tags for given agent
    def delete(nanite)
      delete_elems(nanite, "s-#{nanite}", 'naniteservices')
      delete_elems(nanite, "tg-#{nanite}", 'nanitestags')
    end

    # Services implemented by given agent
    def services(nanite)
      @redis.set_members("s-#{nanite}")
    end

    # Tags exposed by given agent
    def tags(nanite)
      @redis.set_members("tg-#{nanite}")
    end

    # Retrieve all agents services
    def all_services
      log_redis_error do
        @redis.set_members('naniteservices')
      end
    end

    # Retrieve all agents tags
    def all_tags
      log_redis_error do
        @redis.set_members('nanitetags')
      end
    end

    # Retrieve nanites implementing given service and exposing given tags
    def nanites_for(service, *tags)
      log_redis_error do
        @redis.set_intersect(tags.dup << service)
      end
    end

    private

    # Store values for given nanite agent
    # Also store reverse lookup information using both a unique and
    # a global key (so it's possible to retrieve that agent value or
    # all related values)
    def store_elems(nanite, elem_key, global_key, values)
      log_redis_error do
        if old_values = @redis.set_members(elem_key)
          (old_values - values).each do |val|
            @redis.set_delete(val, nanite)
            @redis.set_delete(global_key, val)
          end
        end
        @redis.delete(elem_key)
        values.each do |val|
          @redis.set_add(val, nanite)
          @redis.set_add(elem_key, val)
          @redis.set_add(global_key, val)
        end
      end
    end

    # Delete all values for given nanite agent
    # Also delete reverse lookup information
    def delete_elems(nanite, elem_key, global_key)
      log_redis_error do
        (@redis.set_members(elem_key)||[]).each do |val|
          @redis.set_delete(val, nanite)
          if @redis.set_count(val) == 0
            @redis.delete(val)
            @redis.set_delete(global_key, val)
          end
        end
        @redis.delete(elem_key)
      end
    end

    # Helper method, catch and log errors
    def log_redis_error(&blk)
      blk.call
    rescue Exception => e
      Nanite::Log.warn("redis error in method: #{caller[0]}")
      raise e
    end

  end
end