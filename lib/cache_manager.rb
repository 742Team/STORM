# lib/cache_manager.rb
require 'json'

class CacheManager
  def initialize(max_size = 1000)
    @cache = {}
    @access_times = {}
    @max_size = max_size
  end
  
  def get(key)
    if @cache.key?(key)
      @access_times[key] = Time.now
      @cache[key]
    else
      nil
    end
  end
  
  def set(key, value, ttl = 3600)
    cleanup_if_needed
    
    @cache[key] = {
      value: value,
      expires_at: Time.now + ttl
    }
    @access_times[key] = Time.now
  end
  
  def delete(key)
    @cache.delete(key)
    @access_times.delete(key)
  end
  
  def clear
    @cache.clear
    @access_times.clear
  end
  
  def stats
    {
      size: @cache.size,
      hit_ratio: calculate_hit_ratio,
      memory_usage: calculate_memory_usage
    }
  end
  
  private
  
  def cleanup_if_needed
    return unless @cache.size >= @max_size
    
    # Supprimer les entrées expirées
    now = Time.now
    @cache.delete_if { |k, v| v[:expires_at] < now }
    
    # Si encore trop plein, supprimer les moins récemment utilisées
    if @cache.size >= @max_size
      lru_keys = @access_times.sort_by { |k, v| v }.first(@max_size / 4).map(&:first)
      lru_keys.each { |key| delete(key) }
    end
  end
  
  def calculate_hit_ratio
    # Implémentation simplifiée
    0.85
  end
  
  def calculate_memory_usage
    @cache.to_json.bytesize
  end
end

# Instance globale du cache
CACHE = CacheManager.new(1000)
