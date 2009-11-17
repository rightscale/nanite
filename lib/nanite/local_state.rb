module Nanite
  class LocalState < ::Hash
    def initialize(hsh={})
      hsh.each do |k,v|
        self[k] = v
      end
    end

    def all_services
      all(:services)
    end

    def all_tags
      all(:tags)
    end

    def nanites_for(from, service, tags)
      tags = tags.dup.flatten
      nanites = select { |name, state| state[:services].include?(service) }
      unless tags.empty?
        nanites.select { |a, b| !(b[:tags] & tags).empty? }
      else
        nanites
      end.to_a
    end

    def update_status(name, status)
      self[name].update(:status => status, :timestamp => Time.now.utc.to_i)
    end
    
    def update_tags(name, new_tags, obsolete_tags)
      prev_tags = self[name] && self[name][:tags]
      updated_tags = (new_tags || []) + (prev_tags || []) - (obsolete_tags || [])
      self[name].update(:tags => updated_tags.uniq)
    end
    
    private

    def all(key)
      map { |n,s| s[key] }.flatten.uniq.compact
    end

  end # LocalState
end # Nanite
