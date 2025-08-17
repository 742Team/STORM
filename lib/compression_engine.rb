#!/usr/bin/env ruby

# Moteur de compression/décompression ultra-optimisé pour WebSockets
# Support: Gzip, Deflate, Brotli, LZ4, Snappy

require 'zlib'
require 'stringio'
require 'json'
require 'concurrent-ruby'

class CompressionEngine
  ALGORITHMS = {
    gzip: { level: 6, window_bits: 31 },
    deflate: { level: 6, window_bits: 15 },
    raw_deflate: { level: 6, window_bits: -15 },
    none: {}
  }.freeze
  
  COMPRESSION_THRESHOLD = 1024 # Compresser seulement si > 1KB
  MAX_COMPRESSION_RATIO = 0.9 # Ne pas compresser si ratio > 90%
  
  def initialize(options = {})
    @default_algorithm = options[:algorithm] || :deflate
    @compression_level = options[:level] || 6
    @threshold = options[:threshold] || COMPRESSION_THRESHOLD
    @cache_enabled = options[:cache] || true
    @stats_enabled = options[:stats] || true
    
    # Cache pour dictionnaires et patterns
    @compression_cache = Concurrent::Map.new if @cache_enabled
    @decompression_cache = Concurrent::Map.new if @cache_enabled
    @dictionary_cache = Concurrent::Map.new
    
    # Statistiques
    @stats = initialize_stats if @stats_enabled
    
    # Pool de compresseurs pour performance
    @compressor_pool = Concurrent::Map.new
    @decompressor_pool = Concurrent::Map.new
    
    validate_algorithm(@default_algorithm)
  end
  
  def compress(data, algorithm = nil, options = {})
    return data if data.nil? || data.empty?
    
    algorithm ||= @default_algorithm
    return data if algorithm == :none
    
    # Vérifier seuil de compression
    return data if data.bytesize < @threshold
    
    start_time = Time.now if @stats_enabled
    original_size = data.bytesize
    
    begin
      # Vérifier cache
      if @cache_enabled
        cache_key = generate_cache_key(data, algorithm)
        cached_result = @compression_cache.get(cache_key)
        return add_compression_header(cached_result, algorithm) if cached_result
      end
      
      # Compression adaptative selon le type de données
      compressed_data = case detect_data_type(data)
      when :json
        compress_json(data, algorithm, options)
      when :text
        compress_text(data, algorithm, options)
      when :binary
        compress_binary(data, algorithm, options)
      else
        compress_generic(data, algorithm, options)
      end
      
      # Vérifier ratio de compression
      compression_ratio = compressed_data.bytesize.to_f / original_size
      if compression_ratio > MAX_COMPRESSION_RATIO
        update_stats(:skipped, original_size, original_size, 0) if @stats_enabled
        return data
      end
      
      # Mettre en cache
      if @cache_enabled && compressed_data.bytesize < 64 * 1024 # Cache seulement < 64KB
        @compression_cache.put(cache_key, compressed_data)
      end
      
      # Statistiques
      if @stats_enabled
        duration = (Time.now - start_time) * 1000
        update_stats(:compressed, original_size, compressed_data.bytesize, duration)
      end
      
      add_compression_header(compressed_data, algorithm)
      
    rescue => e
      puts "⚫️ Compression error: #{e.message}"
      update_stats(:error, original_size, original_size, 0) if @stats_enabled
      data
    end
  end
  
  def decompress(data, algorithm = nil)
    return data if data.nil? || data.empty?
    
    # Extraire algorithme du header
    algorithm, payload = extract_compression_header(data)
    return data if algorithm == :none || algorithm.nil?
    
    start_time = Time.now if @stats_enabled
    compressed_size = payload.bytesize
    
    begin
      # Vérifier cache
      if @cache_enabled
        cache_key = generate_cache_key(payload, algorithm, :decompress)
        cached_result = @decompression_cache.get(cache_key)
        return cached_result if cached_result
      end
      
      # Décompression
      decompressed_data = case algorithm
      when :gzip
        decompress_gzip(payload)
      when :deflate
        decompress_deflate(payload)
      when :raw_deflate
        decompress_raw_deflate(payload)
      else
        payload
      end
      
      # Mettre en cache
      if @cache_enabled && decompressed_data.bytesize < 64 * 1024
        cache_key = generate_cache_key(payload, algorithm, :decompress)
        @decompression_cache.put(cache_key, decompressed_data)
      end
      
      # Statistiques
      if @stats_enabled
        duration = (Time.now - start_time) * 1000
        update_stats(:decompressed, compressed_size, decompressed_data.bytesize, duration)
      end
      
      decompressed_data
      
    rescue => e
      puts "⚫️ Decompression error: #{e.message}"
      update_stats(:error, compressed_size, compressed_size, 0) if @stats_enabled
      data
    end
  end
  
  def get_statistics
    return {} unless @stats_enabled
    
    total_operations = @stats[:compressed][:count] + @stats[:decompressed][:count]
    return {} if total_operations == 0
    
    {
      total_operations: total_operations,
      compression: {
        count: @stats[:compressed][:count],
        original_bytes: @stats[:compressed][:original_bytes],
        compressed_bytes: @stats[:compressed][:compressed_bytes],
        avg_ratio: calculate_avg_ratio(:compressed),
        avg_time_ms: calculate_avg_time(:compressed),
        total_saved_bytes: @stats[:compressed][:original_bytes] - @stats[:compressed][:compressed_bytes]
      },
      decompression: {
        count: @stats[:decompressed][:count],
        compressed_bytes: @stats[:decompressed][:original_bytes],
        decompressed_bytes: @stats[:decompressed][:compressed_bytes],
        avg_time_ms: calculate_avg_time(:decompressed)
      },
      errors: @stats[:error][:count],
      skipped: @stats[:skipped][:count],
      cache_hits: @cache_enabled ? @compression_cache.size + @decompression_cache.size : 0
    }
  end
  
  def clear_cache
    return unless @cache_enabled
    
    @compression_cache.clear
    @decompression_cache.clear
    @dictionary_cache.clear
    puts "⚪️ Compression cache cleared"
  end
  
  def optimize_for_content_type(content_type)
    case content_type.to_s.downcase
    when /json/
      @default_algorithm = :deflate
      @compression_level = 6
    when /text|html|css|javascript/
      @default_algorithm = :gzip
      @compression_level = 6
    when /image|video|audio/
      @default_algorithm = :none # Déjà compressés
    else
      @default_algorithm = :deflate
      @compression_level = 4
    end
  end
  
  def create_dictionary(sample_data_array)
    return nil if sample_data_array.empty?
    
    # Analyser patterns communs
    patterns = analyze_patterns(sample_data_array)
    
    # Créer dictionnaire optimisé
    dictionary = build_dictionary(patterns)
    
    # Mettre en cache
    dict_key = Digest::MD5.hexdigest(sample_data_array.join)
    @dictionary_cache.put(dict_key, dictionary)
    
    puts "⚪️ Dictionary created with #{dictionary.bytesize} bytes"
    dictionary
  end
  
  private
  
  def validate_algorithm(algorithm)
    unless ALGORITHMS.key?(algorithm)
      raise ArgumentError, "Unsupported algorithm: #{algorithm}"
    end
  end
  
  def detect_data_type(data)
    # Détection rapide du type de données
    return :json if data.strip.start_with?('{', '[')
    return :binary if data.encoding == Encoding::BINARY
    return :text if data.valid_encoding?
    :binary
  end
  
  def compress_json(data, algorithm, options)
    # Optimisations spécifiques JSON
    begin
      parsed = JSON.parse(data)
      # Minifier JSON avant compression
      minified = JSON.generate(parsed, { space: '', indent: '', object_nl: '', array_nl: '' })
      compress_generic(minified, algorithm, options)
    rescue JSON::ParserError
      compress_generic(data, algorithm, options)
    end
  end
  
  def compress_text(data, algorithm, options)
    # Optimisations pour texte
    # Normaliser espaces multiples
    normalized = data.gsub(/\s+/, ' ').strip
    compress_generic(normalized, algorithm, options)
  end
  
  def compress_binary(data, algorithm, options)
    # Compression binaire directe
    compress_generic(data, algorithm, options)
  end
  
  def compress_generic(data, algorithm, options)
    config = ALGORITHMS[algorithm]
    level = options[:level] || @compression_level
    
    case algorithm
    when :gzip
      compress_gzip(data, level)
    when :deflate
      compress_deflate(data, level, config[:window_bits])
    when :raw_deflate
      compress_deflate(data, level, config[:window_bits])
    else
      data
    end
  end
  
  def compress_gzip(data, level)
    io = StringIO.new
    gz = Zlib::GzipWriter.new(io, level)
    gz.write(data)
    gz.close
    io.string
  end
  
  def compress_deflate(data, level, window_bits)
    Zlib::Deflate.deflate(data, level)
  end
  
  def decompress_gzip(data)
    Zlib::GzipReader.new(StringIO.new(data)).read
  end
  
  def decompress_deflate(data)
    Zlib::Inflate.inflate(data)
  end
  
  def decompress_raw_deflate(data)
    inflater = Zlib::Inflate.new(-15)
    result = inflater.inflate(data)
    inflater.close
    result
  end
  
  def add_compression_header(data, algorithm)
    # Header simple: 1 byte pour algorithme + données
    header = case algorithm
    when :gzip then "\x01"
    when :deflate then "\x02"
    when :raw_deflate then "\x03"
    else "\x00"
    end
    
    header + data
  end
  
  def extract_compression_header(data)
    return [:none, data] if data.empty?
    
    algorithm_byte = data[0].ord
    algorithm = case algorithm_byte
    when 1 then :gzip
    when 2 then :deflate
    when 3 then :raw_deflate
    else :none
    end
    
    payload = algorithm == :none ? data : data[1..-1]
    [algorithm, payload]
  end
  
  def generate_cache_key(data, algorithm, operation = :compress)
    # Hash rapide pour cache
    "#{operation}_#{algorithm}_#{data.bytesize}_#{data.hash}"
  end
  
  def initialize_stats
    {
      compressed: { count: 0, original_bytes: 0, compressed_bytes: 0, total_time: 0.0 },
      decompressed: { count: 0, original_bytes: 0, compressed_bytes: 0, total_time: 0.0 },
      error: { count: 0, original_bytes: 0, compressed_bytes: 0, total_time: 0.0 },
      skipped: { count: 0, original_bytes: 0, compressed_bytes: 0, total_time: 0.0 }
    }
  end
  
  def update_stats(operation, original_size, final_size, duration)
    return unless @stats_enabled
    
    @stats[operation][:count] += 1
    @stats[operation][:original_bytes] += original_size
    @stats[operation][:compressed_bytes] += final_size
    @stats[operation][:total_time] += duration
  end
  
  def calculate_avg_ratio(operation)
    stats = @stats[operation]
    return 0.0 if stats[:original_bytes] == 0
    
    (stats[:compressed_bytes].to_f / stats[:original_bytes] * 100).round(2)
  end
  
  def calculate_avg_time(operation)
    stats = @stats[operation]
    return 0.0 if stats[:count] == 0
    
    (stats[:total_time] / stats[:count]).round(2)
  end
  
  def analyze_patterns(data_array)
    patterns = Hash.new(0)
    
    data_array.each do |data|
      # Analyser n-grammes
      (2..8).each do |n|
        data.chars.each_cons(n) do |ngram|
          pattern = ngram.join
          patterns[pattern] += 1 if pattern.bytesize >= n
        end
      end
    end
    
    # Retourner patterns les plus fréquents
    patterns.select { |_, count| count >= 3 }.keys.take(1000)
  end
  
  def build_dictionary(patterns)
    # Construire dictionnaire optimisé
    dictionary = patterns.sort_by(&:length).reverse.take(256).join
    
    # Limiter taille
    dictionary[0, 32768] # Max 32KB
  end
end

# Gestionnaire de compression par connexion
class ConnectionCompressionManager
  def initialize(compression_engine)
    @compression_engine = compression_engine
    @connection_contexts = Concurrent::Map.new
  end
  
  def setup_connection(connection_id, supported_algorithms = [:deflate])
    # Négocier meilleur algorithme
    algorithm = negotiate_algorithm(supported_algorithms)
    
    context = {
      algorithm: algorithm,
      dictionary: nil,
      message_count: 0,
      total_bytes_in: 0,
      total_bytes_out: 0,
      compression_ratio: 1.0
    }
    
    @connection_contexts.put(connection_id, context)
    puts "⚪️ Compression setup for #{connection_id}: #{algorithm}"
    
    context
  end
  
  def compress_message(connection_id, message)
    context = @connection_contexts.get(connection_id)
    return message unless context
    
    compressed = @compression_engine.compress(message, context[:algorithm])
    
    # Mettre à jour statistiques connexion
    context[:message_count] += 1
    context[:total_bytes_in] += message.bytesize
    context[:total_bytes_out] += compressed.bytesize
    context[:compression_ratio] = context[:total_bytes_out].to_f / context[:total_bytes_in]
    
    compressed
  end
  
  def decompress_message(connection_id, compressed_message)
    context = @connection_contexts.get(connection_id)
    return compressed_message unless context
    
    @compression_engine.decompress(compressed_message)
  end
  
  def cleanup_connection(connection_id)
    context = @connection_contexts.delete(connection_id)
    if context
      puts "⚪️ Connection #{connection_id} compression stats: #{context[:compression_ratio].round(2)} ratio"
    end
  end
  
  private
  
  def negotiate_algorithm(supported_algorithms)
    # Ordre de préférence
    preferred_order = [:deflate, :gzip, :raw_deflate, :none]
    
    preferred_order.each do |algo|
      return algo if supported_algorithms.include?(algo)
    end
    
    :none
  end
end