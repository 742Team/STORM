class GetProfileInfo < BaseCommand
  def initialize(controller)
    super(controller)
    @name        = "Profile Info"
    @description = "Show a user's profile information"
    @command     = "/gpi"
    @aliases     = ["/getprofileinfo", "/profileinfo"]
  end

  def execute(parts, driver, chat_room, username)
    user_manager = @controller.instance_variable_get(:@user_manager)
    profile_manager = @controller.instance_variable_get(:@profile_manager)
    usr    = parts[1]&.strip
    target = usr.nil? ? username : usr
    usr_id = user_manager.get_user_id(target)
    prf    = profile_manager.get_profile(usr_id)

    unless usr_id
    driver.text("⚠️ User “#{target}” not found.")
    return
    end
    unless prf
    driver.text ("⚠️ No profile found for user ID #{usr_id} (#{target}).")
    return
    end



    driver.text(<<~MSG)
      Profile Information for #{target}:
      Avatar URL:      #{prf[:avatar_url]}
      Bio:             #{prf[:bio]}
      Location:        #{prf[:location]}
      Website:         #{prf[:website]}
      Social Links:    #{prf[:social_links].join(', ')}
      Status:          #{prf[:status]}
      Last Seen:       #{Time.at(prf[:last_seen]).strftime('%Y-%m-%d %H:%M:%S')}
      Created At:      #{Time.at(prf[:created_at]).strftime('%Y-%m-%d %H:%M:%S')}
      Updated At:      #{Time.at(prf[:updated_at]).strftime('%Y-%m-%d %H:%M:%S')}
    MSG

    nil
  end
end
