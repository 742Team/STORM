# Helper methods for extracting metadata from files
module MetadataHelpers
  def extract_file_metadata(file_path, mime_type)
    metadata = {
      "basic" => {
        "filename" => File.basename(file_path),
        "size" => File.size(file_path),
        "mime_type" => mime_type,
        "created_at" => File.ctime(file_path).iso8601,
        "modified_at" => File.mtime(file_path).iso8601
      }
    }
    
    # Extract additional metadata based on file type
    if defined?(MiniMagick) && mime_type.start_with?('image/')
      extract_image_metadata(file_path, metadata)
    elsif mime_type.start_with?('video/')
      extract_video_metadata(file_path, metadata)
    elsif mime_type.start_with?('audio/')
      extract_audio_metadata(file_path, metadata)
    end
    
    metadata
  end
  
  private
  
  def extract_image_metadata(file_path, metadata)
    begin
      image = MiniMagick::Image.new(file_path)
      metadata["image"] = {
        "width" => image.width,
        "height" => image.height,
        "format" => image.type.downcase,
        "colorspace" => image[:colorspace],
        "resolution" => {
          "x" => image[:resolution]&.fetch("x", nil),
          "y" => image[:resolution]&.fetch("y", nil)
        }
      }
      
      # Try to extract EXIF data if available
      exif = image.exif
      unless exif.empty?
        metadata["exif"] = {}
        exif.each do |key, value|
          metadata["exif"][key] = value unless value.to_s.empty?
        end
      end
    rescue => e
      puts "Error extracting image metadata: #{e.message}"
    end
  end
  
  def extract_video_metadata(file_path, metadata)
    # Basic video metadata (could be enhanced with ffmpeg if available)
    metadata["video"] = {
      "format" => File.extname(file_path).sub('.', '').downcase
    }
  end
  
  def extract_audio_metadata(file_path, metadata)
    # Enhanced audio metadata with track information
    begin
      # Try to load audio metadata extraction libraries
      begin
        require 'taglib'
      rescue LoadError
        puts "TagLib not available - using basic audio metadata"
      end
      
      filename = File.basename(file_path)
      extension = File.extname(file_path).downcase
      basename = File.basename(file_path, extension)
      
      # Try to extract meaningful title from the filename
      # Remove timestamp and UUID pattern
      clean_title = basename.gsub(/^\d+_[a-f0-9\-]+_/, '')
      
      # Try to parse artist and title if they're separated by common patterns
      artist = "Unknown Artist"
      title = clean_title
      
      # Check for common patterns like "Artist - Title" or "Title_Artist"
      if clean_title.include?(' - ')
        parts = clean_title.split(' - ', 2)
        artist = parts[0].strip
        title = parts[1].strip
      elsif clean_title.include?('_')
        # Try to intelligently parse underscores
        parts = clean_title.split('_')
        if parts.length >= 2
          # If we have a pattern like "01_Title_Artist" or "Title_Artist"
          if parts[0] =~ /^\d+$/
            # First part is a track number
            title = parts[1..-1].join(' ')
            
            # Check if the last part might be the artist
            if parts.length >= 3 && parts[-1].length > 1
              artist = parts[-1]
              title = parts[1..-2].join(' ')
            end
          else
            title = parts.join(' ')
            
            # Check if the last part might be the artist
            if parts.length >= 2 && parts[-1].length > 1
              artist = parts[-1]
              title = parts[0..-2].join(' ')
            end
          end
        end
      end
      
      # Default track data with improved title parsing
      track_data = {
        "title" => title,
        "artist" => artist,
        "album" => "",
        "releaseDate" => "",
        "coverUrl" => nil
      }
      
      # Extract ID3 tags if TagLib is available
      if defined?(TagLib)
        case extension
        when '.mp3'
          extract_mp3_metadata(file_path, track_data)
        when '.ogg'
          extract_ogg_metadata(file_path, track_data)
        when '.flac'
          extract_flac_metadata(file_path, track_data)
        end
      end
      
      metadata["audio"] = {
        "format" => extension.sub('.', '').downcase,
        "track" => track_data
      }
    rescue => e
      puts "Error extracting audio metadata: #{e.message}"
      metadata["audio"] = {
        "format" => File.extname(file_path).sub('.', '').downcase,
        "track" => {
          "title" => File.basename(file_path, File.extname(file_path)),
          "artist" => "Unknown Artist",
          "album" => "",
          "releaseDate" => "",
          "coverUrl" => nil
        }
      }
    end
  end
  
  def extract_mp3_metadata(file_path, track_data)
    TagLib::MPEG::File.open(file_path) do |file|
      if file.id3v2_tag
        tag = file.id3v2_tag
        # Use lowercase keys to be consistent with other formats
        track_data["title"] = tag.title unless tag.title.empty?
        track_data["artist"] = tag.artist unless tag.artist.empty?
        track_data["album"] = tag.album unless tag.album.empty?
        track_data["releaseDate"] = tag.year.to_s unless tag.year.zero?
        track_data["genre"] = tag.genre unless tag.genre.empty?
        track_data["track"] = tag.track.to_s unless tag.track.zero?
        
        # Extract cover art if available
        if !tag.frame_list('APIC').empty?
          cover_art = tag.frame_list('APIC').first
          if cover_art
            cover_filename = "#{SecureRandom.uuid}_cover.jpg"
            cover_path = File.join(settings.public_folder, 'uploads', cover_filename)
            File.open(cover_path, 'wb') { |f| f.write(cover_art.picture) }
            track_data["coverUrl"] = "/uploads/#{cover_filename}"
          end
        end
      end
    end
  end
  
  def extract_ogg_metadata(file_path, track_data)
    TagLib::Ogg::Vorbis::File.open(file_path) do |file|
      tag = file.tag
      track_data["title"] = tag.title unless tag.title.empty?
      track_data["artist"] = tag.artist unless tag.artist.empty?
      track_data["album"] = tag.album unless tag.album.empty?
      track_data["releaseDate"] = tag.year.to_s unless tag.year.zero?
    end
  end
  
  def extract_flac_metadata(file_path, track_data)
    TagLib::FLAC::File.open(file_path) do |file|
      tag = file.tag
      track_data["title"] = tag.title unless tag.title.empty?
      track_data["artist"] = tag.artist unless tag.artist.empty?
      track_data["album"] = tag.album unless tag.album.empty?
      track_data["releaseDate"] = tag.year.to_s unless tag.year.zero?
      
      # Extract cover art if available
      if !file.picture_list.empty?
        picture = file.picture_list.first
        if picture
          cover_filename = "#{SecureRandom.uuid}_cover.jpg"
          cover_path = File.join(settings.public_folder, 'uploads', cover_filename)
          File.open(cover_path, 'wb') { |f| f.write(picture.data) }
          track_data["coverUrl"] = "/uploads/#{cover_filename}"
        end
      end
    end
  end
end