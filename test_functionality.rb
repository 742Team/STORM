#!/usr/bin/env ruby
# Script de test des fonctionnalités STORM sans dépendances externes

require 'socket'
require 'json'

class StormTester
  def initialize
    @test_results = []
    puts "=== STORM Functionality Tester ==="
    puts "Testing core functionality without external dependencies\n\n"
  end

  def test_file_structure
    puts "1. Testing file structure..."
    
    required_files = [
      'srv_message.rb',
      'srv_upload.rb', 
      'auth_app.rb',
      'Message/controllers/chat_controller.rb',
      'Message/models/chat_room.rb'
    ]
    
    required_files.each do |file|
      if File.exist?(file)
        puts "  ✓ #{file} exists"
        @test_results << { test: "File #{file}", status: "PASS" }
      else
        puts "  ✗ #{file} missing"
        @test_results << { test: "File #{file}", status: "FAIL" }
      end
    end
    puts
  end

  def test_command_files
    puts "2. Testing command files..."
    
    command_dirs = [
      'Message/commands/Appearance',
      'Message/commands/Chat_Management',
      'Message/commands/Media_Commands',
      'Message/commands/Room_Management',
      'Message/commands/User_Management'
    ]
    
    command_dirs.each do |dir|
      if Dir.exist?(dir)
        files = Dir.glob("#{dir}/*.rb")
        puts "  ✓ #{dir}: #{files.length} command files"
        @test_results << { test: "Commands in #{dir}", status: "PASS", count: files.length }
        
        files.each do |file|
          puts "    - #{File.basename(file)}"
        end
      else
        puts "  ✗ #{dir} missing"
        @test_results << { test: "Commands in #{dir}", status: "FAIL" }
      end
    end
    puts
  end

  def test_syntax
    puts "3. Testing Ruby syntax..."
    
    ruby_files = Dir.glob('**/*.rb')
    syntax_errors = []
    
    ruby_files.each do |file|
      result = `ruby -c "#{file}" 2>&1`
      if $?.success?
        puts "  ✓ #{file} - syntax OK"
        @test_results << { test: "Syntax #{file}", status: "PASS" }
      else
        puts "  ✗ #{file} - syntax error: #{result.strip}"
        @test_results << { test: "Syntax #{file}", status: "FAIL", error: result.strip }
        syntax_errors << { file: file, error: result.strip }
      end
    end
    
    if syntax_errors.empty?
      puts "  All files have valid syntax!"
    else
      puts "  #{syntax_errors.length} files have syntax errors"
    end
    puts
  end

  def test_port_availability
    puts "4. Testing port availability..."
    
    ports = [3630, 4567, 3000] # Message server, Auth server, Upload server
    
    ports.each do |port|
      begin
        server = TCPServer.new('localhost', port)
        server.close
        puts "  ✓ Port #{port} is available"
        @test_results << { test: "Port #{port}", status: "AVAILABLE" }
      rescue Errno::EADDRINUSE
        puts "  ! Port #{port} is in use"
        @test_results << { test: "Port #{port}", status: "IN_USE" }
      rescue => e
        puts "  ✗ Port #{port} error: #{e.message}"
        @test_results << { test: "Port #{port}", status: "ERROR", error: e.message }
      end
    end
    puts
  end

  def generate_report
    puts "=== TEST SUMMARY ==="
    
    passed = @test_results.count { |r| r[:status] == "PASS" }
    failed = @test_results.count { |r| r[:status] == "FAIL" }
    other = @test_results.length - passed - failed
    
    puts "Total tests: #{@test_results.length}"
    puts "Passed: #{passed}"
    puts "Failed: #{failed}"
    puts "Other: #{other}"
    puts
    
    if failed > 0
      puts "FAILED TESTS:"
      @test_results.select { |r| r[:status] == "FAIL" }.each do |result|
        puts "  - #{result[:test]}: #{result[:error] || 'Failed'}"
      end
    end
    
    puts "\n=== RECOMMENDATIONS ==="
    puts "1. Install required Ruby gems: bundle install"
    puts "2. Check syntax errors and fix them"
    puts "3. Ensure all command files are properly implemented"
    puts "4. Test network connectivity on required ports"
  end

  def run_all_tests
    test_file_structure
    test_command_files
    test_syntax
    test_port_availability
    generate_report
  end
end

# Run the tests
tester = StormTester.new
tester.run_all_tests