require 'redis'
require 'redis_tag_store'

module Nanite
  class State
    include Enumerable
    
    # This class encapsulates the state of a nanite system using redis as the 
    # data store and a provided tag store. For a nanite with the identity
    # 'nanite-foobar' we store the following:
    #
    # nanite-foobar: 0.72        # load average or 'status'
    # t-nanite-foobar: 123456789 # unix timestamp of the last state update
    #
    # The tag store is used to store the associated services and tags.
    #
    # A tag store should provide the following methods:
    #  - services(nanite): Retrieve services implemented by given agent
    #  - tags(nanite): Retrieve tags implemented by given agent
    #  - all_services: Retrieve all services implemented by all agents
    #  - all_tags: Retrieve all tags exposed by all agents
    #  - store(nanite, services, tags): Store agent's services and tags
    #  - delete(nanite): Delete all entries associated with given agent
    #  - nanites_for(service, tags): Retrieve agents implementing given service
    #                                and exposing given tags
    #
    # The default implementation for the tag store reuses Redis.
  
    def initialize(redis, tag_store=nil)
      Nanite::Log.info("[setup] initializing redis state: #{redis}")
      host, port = redis.split(':')
      host ||= '127.0.0.1'
      port ||= '6379'
      @redis = Redis.new :host => host, :port => port
      @tag_store ||= RedisTagStore.new(@redis)
    end
    
    def log_redis_error(meth,&blk)
      blk.call
    rescue Exception => e
      Nanite::Log.info("redis error in method: #{meth}")
      raise e
    end
    
    def [](nanite)
      log_redis_error("[]") do
        status = @redis[nanite]
        timestamp = @redis["t-#{nanite}"]
        services = @tag_store.services(nanite)
        tags = @tag_store.tags(nanite)
        return nil unless status && timestamp && services
        {:services => services, :status => status, :timestamp => timestamp.to_i, :tags => tags}
      end
    end
    
    def []=(nanite, attributes)
      log_redis_error("[]=") do
        update_state(nanite, attributes[:status], attributes[:services], attributes[:tags])
      end
    end
    
    def delete(nanite)
      log_redis_error("delete") do
        @tag_store.delete(nanite)
        @redis.delete nanite
        @redis.delete "t-#{nanite}"
      end
    end
    
    def all_services
      @tag_store.all_services
    end

    def all_tags
      @tag_store.all_tags
    end
    
    def update_state(name, status, services, tags)
      @tag_store.store(name, services, tags)
      update_status(name, status)
    end

    def update_status(name, status)
      log_redis_error("update_status") do
        @redis[name] = status
        @redis["t-#{name}"] = Time.now.utc.to_i
      end
    end
    
    def list_nanites
      log_redis_error("list_nanites") do
        @redis.keys("nanite-*")
      end
    end
    
    def size
      list_nanites.size
    end
    
    def each
      list_nanites.each do |nan|
        yield nan, self[nan]
      end
    end
    
    def nanites_for(service, *tags)
      @tag_store.nanites_for(service, tags)
    end

  end
end  