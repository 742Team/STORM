# config/database_pool.rb
require 'sqlite3'
require 'thread'

class DatabasePool
  def initialize(size = 10)
    @size = size
    @connections = Queue.new
    @mutex = Mutex.new
    
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
    SQLite3::Database.new('storm.db')
  end
end

# Instance globale du pool
DB_POOL = DatabasePool.new(10)
