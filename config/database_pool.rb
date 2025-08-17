# config/database_pool.rb
require 'sqlite3'
require 'thread'
require_relative 'database_config'

class DatabasePool
  def initialize(size = 10)
    @size = size
    @connections = Queue.new
    @mutex = Mutex.new
    
    # Initialiser la base de données avant de créer les connexions
    DatabaseConfig.setup_database
    
    @size.times do
      @connections << create_connection
    end
  end
  
  def with_connection
    connection = @connections.pop
    begin
      yield connection
    ensure
      @connections << connection
    end
  end
  
  private
  
  def create_connection
    DatabaseConfig.get_connection
  end
end

# Instance globale du pool
DB_POOL = DatabasePool.new(10)
