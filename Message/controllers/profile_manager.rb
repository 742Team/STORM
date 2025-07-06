class ProfileManager
  def initialize(controller)
    @controller = controller
  end
  
  def create_profile(user_id)
    begin
      db = @controller.db_connection
      # Check if profile already exists
      result = db.execute("SELECT id FROM user_profiles WHERE user_id = ?", [user_id])
      
      if result.empty?
        # Create new profile
        current_time = Time.now.to_i
        db.execute(
          "INSERT INTO user_profiles (user_id, created_at, updated_at) VALUES (?, ?, ?)",
          [user_id, current_time, current_time]
        )
      end
      db.close
      true
    rescue => e
      puts "Error creating user profile: #{e.message}"
      false
    end
  end
  
  def update_profile(user_id, profile_data)
    begin
      # Sanitize and prepare data
      avatar_url = profile_data[:avatar_url]
      bio = profile_data[:bio]
      location = profile_data[:location]
      website = profile_data[:website]
      social_links = profile_data[:social_links].to_json if profile_data[:social_links]
      status = profile_data[:status]
      
      db = @controller.db_connection
      # Update profile
      db.execute(
        "UPDATE user_profiles SET 
         avatar_url = ?, bio = ?, location = ?, website = ?, 
         social_links = ?, status = ?, updated_at = ? 
         WHERE user_id = ?",
        [avatar_url, bio, location, website, social_links, status, Time.now.to_i, user_id]
      )
      db.close
      true
    rescue => e
      puts "Error updating user profile: #{e.message}"
      false
    end
  end
  
  def get_profile(user_id)
    begin
      db = @controller.db_connection
      result = db.execute(
        "SELECT avatar_url, bio, location, website, social_links, status, last_seen, created_at, updated_at 
         FROM user_profiles WHERE user_id = ?", 
        [user_id]
      )
      db.close
      
      social_links =
      begin
        JSON.parse(result[4])
      rescue JSON::ParserError
        nil
      end



      if result.empty?
        nil
      else
        {
          avatar_url: result[0][0],
          bio: result[0][1],
          location: result[0][2],
          website: result[0][3],
          social_links: social_links,
          status: result[0][5],
          last_seen: result[0][6],
          created_at: result[0][7],
          updated_at: result[0][8]
        }
      end
    rescue => e
      puts "Error getting user profile: #{e.message}"
      nil
    end
  end
  
  def update_last_seen(user_id)
    begin
      db = @controller.db_connection
      db.execute(
        "UPDATE user_profiles SET last_seen = ? WHERE user_id = ?",
        [Time.now.to_i, user_id]
      )
      db.close
      true
    rescue => e
      puts "Error updating last seen: #{e.message}"
      false
    end
  end
end