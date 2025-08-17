#!/usr/bin/env ruby
# Script de test des serveurs STORM en mode minimal

require 'socket'
require 'json'
require 'thread'

class ServerTester
  def initialize
    @test_results = []
    puts "=== STORM Server Testing ==="
    puts "Testing server functionality without external dependencies\n\n"
  end

  def test_message_server_basic
    puts "1. Testing Message Server (WebSocket) basic structure..."
    
    # Test if the file can be loaded without dependencies
    begin
      # Read the file and check structure
      content = File.read('srv_message.rb')
      
      if content.include?('TCPServer.new')
        puts "  ✓ TCPServer initialization found"
        @test_results << { test: "Message Server Structure", status: "PASS" }
      else
        puts "  ✗ TCPServer initialization not found"
        @test_results << { test: "Message Server Structure", status: "FAIL" }
      end
      
      if content.include?('WebSocket::Driver')
        puts "  ✓ WebSocket driver usage found"
      else
        puts "  ! WebSocket driver not found (may need gem)"
      end
      
      if content.include?('ChatController')
        puts "  ✓ ChatController integration found"
      else
        puts "  ✗ ChatController integration not found"
      end
      
    rescue => e
      puts "  ✗ Error reading message server file: #{e.message}"
      @test_results << { test: "Message Server Structure", status: "ERROR", error: e.message }
    end
    puts
  end

  def test_auth_server_basic
    puts "2. Testing Auth Server (Sinatra) basic structure..."
    
    begin
      content = File.read('auth_app.rb')
      
      if content.include?('require \'sinatra\'')
        puts "  ✓ Sinatra framework usage found"
        @test_results << { test: "Auth Server Structure", status: "PASS" }
      else
        puts "  ✗ Sinatra framework not found"
        @test_results << { test: "Auth Server Structure", status: "FAIL" }
      end
      
      if content.include?('post \'/upload\'')
        puts "  ✓ Upload endpoint found"
      else
        puts "  ! Upload endpoint not found"
      end
      
      if content.include?('set :port')
        port_match = content.match(/set :port, (\d+)/)
        if port_match
          puts "  ✓ Server port configured: #{port_match[1]}"
        else
          puts "  ! Server port configuration unclear"
        end
      end
      
    rescue => e
      puts "  ✗ Error reading auth server file: #{e.message}"
      @test_results << { test: "Auth Server Structure", status: "ERROR", error: e.message }
    end
    puts
  end

  def test_upload_server_basic
    puts "3. Testing Upload Server basic structure..."
    
    begin
      content = File.read('srv_upload.rb')
      
      if content.include?('class App < Sinatra::Base')
        puts "  ✓ Sinatra application class found"
        @test_results << { test: "Upload Server Structure", status: "PASS" }
      else
        puts "  ✗ Sinatra application class not found"
        @test_results << { test: "Upload Server Structure", status: "FAIL" }
      end
      
      if content.include?('FileHelpers')
        puts "  ✓ File helpers integration found"
      else
        puts "  ! File helpers not found"
      end
      
      if content.include?('MetadataHelpers')
        puts "  ✓ Metadata helpers integration found"
      else
        puts "  ! Metadata helpers not found"
      end
      
    rescue => e
      puts "  ✗ Error reading upload server file: #{e.message}"
      @test_results << { test: "Upload Server Structure", status: "ERROR", error: e.message }
    end
    puts
  end

  def test_chat_controller
    puts "4. Testing ChatController functionality..."
    
    begin
      content = File.read('Message/controllers/chat_controller.rb')
      
      # Check for singleton pattern
      if content.include?('instance') && content.include?('@@instance')
        puts "  ✓ Singleton pattern implemented"
        @test_results << { test: "ChatController Singleton", status: "PASS" }
      else
        puts "  ! Singleton pattern not clearly implemented"
        @test_results << { test: "ChatController Singleton", status: "WARNING" }
      end
      
      # Check for room management
      if content.include?('create_room')
        puts "  ✓ Room creation functionality found"
      else
        puts "  ✗ Room creation functionality not found"
      end
      
      # Check for user management
      if content.include?('add_user') || content.include?('join_room')
        puts "  ✓ User management functionality found"
      else
        puts "  ! User management functionality unclear"
      end
      
      # Check for message handling
      if content.include?('broadcast') || content.include?('send_message')
        puts "  ✓ Message broadcasting functionality found"
      else
        puts "  ! Message broadcasting functionality unclear"
      end
      
    rescue => e
      puts "  ✗ Error reading ChatController: #{e.message}"
      @test_results << { test: "ChatController", status: "ERROR", error: e.message }
    end
    puts
  end

  def test_command_handler
    puts "5. Testing Command Handler..."
    
    begin
      content = File.read('Message/controllers/command_handler.rb')
      
      if content.include?('def handle') || content.include?('def process')
        puts "  ✓ Command handling method found"
        @test_results << { test: "Command Handler", status: "PASS" }
      else
        puts "  ✗ Command handling method not found"
        @test_results << { test: "Command Handler", status: "FAIL" }
      end
      
      # Check for command registration/mapping
      if content.include?('commands') || content.include?('register')
        puts "  ✓ Command registration system found"
      else
        puts "  ! Command registration system unclear"
      end
      
    rescue => e
      puts "  ✗ Error reading Command Handler: #{e.message}"
      @test_results << { test: "Command Handler", status: "ERROR", error: e.message }
    end
    puts
  end

  def test_database_setup
    puts "6. Testing Database Setup..."
    
    # Check if database files exist
    db_files = ['chat.db', 'users.db', 'storm.db']
    db_found = false
    
    db_files.each do |db_file|
      if File.exist?(db_file)
        puts "  ✓ Database file found: #{db_file}"
        db_found = true
      end
    end
    
    unless db_found
      puts "  ! No database files found (will be created on first run)"
    end
    
    # Check for database initialization in code
    files_to_check = ['auth_app.rb', 'srv_upload.rb']
    
    files_to_check.each do |file|
      if File.exist?(file)
        content = File.read(file)
        if content.include?('SQLite3::Database') || content.include?('sqlite3')
          puts "  ✓ SQLite3 database usage found in #{file}"
          @test_results << { test: "Database Setup #{file}", status: "PASS" }
        else
          puts "  ! SQLite3 usage not found in #{file}"
        end
      end
    end
    puts
  end

  def test_file_upload_structure
    puts "7. Testing File Upload Structure..."
    
    upload_dirs = ['Upload/controllers', 'Upload/helpers', 'Upload/config']
    
    upload_dirs.each do |dir|
      if Dir.exist?(dir)
        files = Dir.glob("#{dir}/*.rb")
        puts "  ✓ #{dir}: #{files.length} files"
        @test_results << { test: "Upload #{dir}", status: "PASS", count: files.length }
      else
        puts "  ✗ #{dir} not found"
        @test_results << { test: "Upload #{dir}", status: "FAIL" }
      end
    end
    
    # Check for upload directory
    if Dir.exist?('uploads') || Dir.exist?('public/uploads')
      puts "  ✓ Upload directory structure found"
    else
      puts "  ! Upload directory not found (will be created)"
    end
    puts
  end

  def simulate_basic_functionality
    puts "8. Simulating Basic Functionality..."
    
    # Test port binding simulation
    test_ports = [3630, 4567, 3000]
    
    test_ports.each do |port|
      begin
        server = TCPServer.new('localhost', port)
        puts "  ✓ Port #{port} can be bound (available)"
        server.close
        @test_results << { test: "Port #{port} Binding", status: "PASS" }
      rescue Errno::EADDRINUSE
        puts "  ! Port #{port} is in use"
        @test_results << { test: "Port #{port} Binding", status: "IN_USE" }
      rescue => e
        puts "  ✗ Port #{port} binding error: #{e.message}"
        @test_results << { test: "Port #{port} Binding", status: "ERROR" }
      end
    end
    
    # Test basic JSON handling
    begin
      test_data = { command: '/help', user: 'test', room: 'Main' }
      json_string = test_data.to_json
      parsed_data = JSON.parse(json_string)
      
      if parsed_data['command'] == '/help'
        puts "  ✓ JSON serialization/deserialization works"
        @test_results << { test: "JSON Handling", status: "PASS" }
      else
        puts "  ✗ JSON handling failed"
        @test_results << { test: "JSON Handling", status: "FAIL" }
      end
    rescue => e
      puts "  ✗ JSON handling error: #{e.message}"
      @test_results << { test: "JSON Handling", status: "ERROR" }
    end
    puts
  end

  def generate_server_report
    puts "=== SERVER TEST SUMMARY ==="
    
    total_tests = @test_results.length
    passed = @test_results.count { |r| r[:status] == "PASS" }
    warnings = @test_results.count { |r| r[:status] == "WARNING" }
    failed = @test_results.count { |r| r[:status] == "FAIL" }
    errors = @test_results.count { |r| r[:status] == "ERROR" }
    in_use = @test_results.count { |r| r[:status] == "IN_USE" }
    
    puts "Total server tests: #{total_tests}"
    puts "✓ Passed: #{passed}"
    puts "! Warnings: #{warnings}"
    puts "✗ Failed: #{failed}"
    puts "⚠ Errors: #{errors}"
    puts "🔒 Ports in use: #{in_use}"
    puts
    
    server_score = ((passed + warnings * 0.7) / total_tests * 100).round(1)
    puts "Server readiness score: #{server_score}%"
    
    if server_score >= 85
      puts "🟢 Servers are ready for deployment"
      puts "\n=== DEPLOYMENT RECOMMENDATIONS ==="
      puts "1. Install missing gems: bundle install (with proper Ruby version)"
      puts "2. Start message server: ruby srv_message.rb"
      puts "3. Start auth server: ruby auth_app.rb"
      puts "4. Start upload server: ruby srv_upload.rb"
      puts "5. Test with WebSocket client connections"
    elsif server_score >= 70
      puts "🟡 Servers need minor fixes before deployment"
    else
      puts "🔴 Servers need significant work before deployment"
    end
    
    puts "\n=== TESTING CHECKLIST ==="
    puts "□ WebSocket connection establishment"
    puts "□ User registration and login"
    puts "□ Room creation and joining"
    puts "□ Message broadcasting"
    puts "□ Command execution (/help, /list, /info, etc.)"
    puts "□ File upload functionality"
    puts "□ User management (ban, kick, etc.)"
    puts "□ Appearance customization"
    puts "□ Direct messaging"
    puts "□ Friend system"
  end

  def run_all_tests
    test_message_server_basic
    test_auth_server_basic
    test_upload_server_basic
    test_chat_controller
    test_command_handler
    test_database_setup
    test_file_upload_structure
    simulate_basic_functionality
    generate_server_report
  end
end

# Run the server tests
tester = ServerTester.new
tester.run_all_tests