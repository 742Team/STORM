require 'bcrypt'
require 'sqlite3'

class UserManager
  def initialize(controller)
    @controller = controller
  end
  
  def register_account(email, password, user)
    return "| Missing fields" if email.empty? || password.empty? || user.empty?
    pd = BCrypt::Password.create(password)
    begin
      db = @controller.db_connection
      db.execute("INSERT INTO users (email, username, password_digest) VALUES (?, ?, ?)", [email, user, pd])
      user_id = db.last_insert_row_id
      db.execute("INSERT INTO user_preferences (user_id) VALUES (?)", [user_id])
      db.close
      "| User registered"
    rescue SQLite3::ConstraintException => e
      "| Email or username used"
    rescue => ex
      "| Error #{ex.message}"
    end
  end

  def login_account(email, password)
    return "| Missing fields" if email.empty? || password.empty?
    begin
      db = @controller.db_connection
      result = db.execute("SELECT * FROM users WHERE email=?", [email])
      db.close
      return "| No account" if result.empty?

      user_data = result[0]
      password_digest = user_data[3]
      username = user_data[2]

      if BCrypt::Password.new(password_digest) == password
        " Logged in as #{username}"
      else
        " Invalid password"
      end
    rescue => ex
      " Error #{ex.message}"
    end
  end
  
  def get_user_id(username)
    begin
      db = @controller.db_connection
      result = db.execute("SELECT id FROM users WHERE username=?", [username])
      db.close
      return result.empty? ? nil : result[0][0]
    rescue => ex
      puts "Erreur lors de la récupération de l'ID utilisateur: #{ex.message}"
      return nil
    end
  end
end