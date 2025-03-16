# Helper methods for file operations
module FileHelpers
  def sanitize_filename(filename)
    extension = File.extname(filename)
    basename = File.basename(filename, extension)

    uuid = SecureRandom.uuid
    timestamp = Time.now.to_i

    sanitized_basename = basename.gsub(/[^\p{Alnum}\p{L}\p{M}\s\-_]/, '_')
    sanitized_basename = sanitized_basename.gsub(/\s+/, '_')
    sanitized_basename = sanitized_basename[0, 100] if sanitized_basename.length > 100

    "#{timestamp}_#{uuid}_#{sanitized_basename}#{extension}"
  end
  
  def detect_mime_type(file_path)
    extension = File.extname(file_path).downcase
    case extension
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    when '.gif'
      'image/gif'
    when '.webp'
      'image/webp'
    when '.mp4'
      'video/mp4'
    when '.webm'
      'video/webm'
    when '.mp3'
      'audio/mpeg'
    when '.wav'
      'audio/wav'
    when '.ogg'
      'audio/ogg'
    when '.pdf'
      'application/pdf'
    else
      'application/octet-stream'
    end
  end
end