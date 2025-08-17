#!/usr/bin/env ruby
# Script de test des commandes STORM

require 'json'

class CommandTester
  def initialize
    @test_results = []
    @commands_tested = 0
    puts "=== STORM Command Functionality Tester ==="
    puts "Testing all available commands\n\n"
  end

  def test_command_files
    puts "1. Testing command file structure and basic functionality..."
    
    command_categories = {
      'Appearance' => [
        'background_command.rb',
        'color_command.rb', 
        'language_command.rb',
        'list_colors_command.rb',
        'stop_music_command.rb',
        'text_color_command.rb',
        'typography_command.rb'
      ],
      'Chat_Management' => [
        'banned_command.rb',
        'clear_client_command.rb',
        'clear_command.rb',
        'history_command.rb',
        'info_command.rb',
        'list_command.rb'
      ],
      'Media_Commands' => [
        'file_command.rb',
        'image_command.rb',
        'music_command.rb',
        'play_music_command.rb',
        'upload_command.rb',
        'volume_command.rb'
      ],
      'Room_Management' => [
        'ban_command.rb',
        'change_password_command.rb',
        'change_room_command.rb',
        'create_room_command.rb',
        'kick_command.rb',
        'list_rooms_command.rb',
        'power_transfer_command.rb'
      ],
      'User_Management' => [
        'accept_friend_command.rb',
        'add_friend_command.rb',
        'change_username_command.rb',
        'decline_friend_command.rb',
        'direct_message_command.rb',
        'friends_list_command.rb',
        'global_direct_message_command.rb',
        'login_command.rb',
        'pending_requests_command.rb',
        'quit_command.rb',
        'register_command.rb',
        'remove_friend_command.rb',
        'save_preferences_command.rb'
      ]
    }
    
    command_categories.each do |category, commands|
      puts "\n  Testing #{category} commands:"
      
      commands.each do |command_file|
        file_path = "Message/commands/#{category}/#{command_file}"
        
        if File.exist?(file_path)
          # Test file syntax
          result = `ruby -c "#{file_path}" 2>&1`
          if $?.success?
            puts "    ✓ #{command_file} - syntax OK"
            
            # Try to analyze command structure
            content = File.read(file_path)
            
            # Check for required methods/structure
            has_execute = content.include?('def execute') || content.include?('def call')
            has_class = content.match(/class\s+\w+/)
            
            if has_execute && has_class
              puts "      ✓ Has proper command structure"
              @test_results << { 
                command: command_file, 
                category: category, 
                status: "PASS", 
                structure: "Complete" 
              }
            else
              puts "      ! Missing execute method or class definition"
              @test_results << { 
                command: command_file, 
                category: category, 
                status: "WARNING", 
                structure: "Incomplete" 
              }
            end
            
            @commands_tested += 1
          else
            puts "    ✗ #{command_file} - syntax error"
            @test_results << { 
              command: command_file, 
              category: category, 
              status: "FAIL", 
              error: result.strip 
            }
          end
        else
          puts "    ✗ #{command_file} - file missing"
          @test_results << { 
            command: command_file, 
            category: category, 
            status: "MISSING" 
          }
        end
      end
    end
    puts
  end

  def test_base_command
    puts "2. Testing base command structure..."
    
    base_files = ['Message/commands/base_command.rb', 'Message/commands/help_command.rb']
    
    base_files.each do |file|
      if File.exist?(file)
        result = `ruby -c "#{file}" 2>&1`
        if $?.success?
          puts "  ✓ #{File.basename(file)} - syntax OK"
          
          content = File.read(file)
          if content.include?('class') && (content.include?('def') || content.include?('module'))
            puts "    ✓ Has proper structure"
            @test_results << { command: File.basename(file), status: "PASS" }
          else
            puts "    ! Structure may be incomplete"
            @test_results << { command: File.basename(file), status: "WARNING" }
          end
        else
          puts "  ✗ #{File.basename(file)} - syntax error"
          @test_results << { command: File.basename(file), status: "FAIL" }
        end
      else
        puts "  ✗ #{File.basename(file)} - missing"
        @test_results << { command: File.basename(file), status: "MISSING" }
      end
    end
    puts
  end

  def test_controllers
    puts "3. Testing controller files..."
    
    controllers = [
      'Message/controllers/chat_controller.rb',
      'Message/controllers/command_handler.rb',
      'Message/controllers/language_manager.rb',
      'Message/controllers/preference_manager.rb',
      'Message/controllers/user_manager.rb'
    ]
    
    controllers.each do |controller|
      if File.exist?(controller)
        result = `ruby -c "#{controller}" 2>&1`
        if $?.success?
          puts "  ✓ #{File.basename(controller)} - syntax OK"
          
          content = File.read(controller)
          if content.include?('class') && content.include?('def')
            puts "    ✓ Has proper controller structure"
            @test_results << { controller: File.basename(controller), status: "PASS" }
          else
            puts "    ! Controller structure may be incomplete"
            @test_results << { controller: File.basename(controller), status: "WARNING" }
          end
        else
          puts "  ✗ #{File.basename(controller)} - syntax error"
          @test_results << { controller: File.basename(controller), status: "FAIL" }
        end
      else
        puts "  ✗ #{File.basename(controller)} - missing"
        @test_results << { controller: File.basename(controller), status: "MISSING" }
      end
    end
    puts
  end

  def analyze_command_coverage
    puts "4. Analyzing command coverage based on README..."
    
    expected_commands = {
      '/cr' => 'create_room_command.rb',
      '/cd' => 'change_room_command.rb', 
      '/info' => 'info_command.rb',
      '/list' => 'list_command.rb',
      '/help' => 'help_command.rb',
      '/history' => 'history_command.rb',
      '/dm' => 'direct_message_command.rb',
      '/quit' => 'quit_command.rb',
      '/color' => 'color_command.rb',
      '/background' => 'background_command.rb',
      '/typo' => 'typography_command.rb',
      '/textcolor' => 'text_color_command.rb',
      '/ban' => 'ban_command.rb',
      '/kick' => 'kick_command.rb',
      '/powerto' => 'power_transfer_command.rb',
      '/register' => 'register_command.rb',
      '/login' => 'login_command.rb'
    }
    
    puts "  Expected commands from README:"
    expected_commands.each do |command, file|
      # Check if corresponding file exists in any category
      found = false
      ['Appearance', 'Chat_Management', 'Media_Commands', 'Room_Management', 'User_Management'].each do |category|
        if File.exist?("Message/commands/#{category}/#{file}")
          puts "    ✓ #{command} -> #{file} (found in #{category})"
          found = true
          break
        end
      end
      
      unless found
        puts "    ✗ #{command} -> #{file} (not found)"
        @test_results << { command: command, expected_file: file, status: "MISSING" }
      end
    end
    puts
  end

  def generate_detailed_report
    puts "=== DETAILED TEST REPORT ==="
    
    total_tests = @test_results.length
    passed = @test_results.count { |r| r[:status] == "PASS" }
    warnings = @test_results.count { |r| r[:status] == "WARNING" }
    failed = @test_results.count { |r| r[:status] == "FAIL" }
    missing = @test_results.count { |r| r[:status] == "MISSING" }
    
    puts "Commands tested: #{@commands_tested}"
    puts "Total tests: #{total_tests}"
    puts "✓ Passed: #{passed}"
    puts "! Warnings: #{warnings}"
    puts "✗ Failed: #{failed}"
    puts "? Missing: #{missing}"
    puts
    
    if warnings > 0
      puts "WARNINGS (may need attention):"
      @test_results.select { |r| r[:status] == "WARNING" }.each do |result|
        puts "  - #{result[:command] || result[:controller]}: #{result[:structure] || 'Structure incomplete'}"
      end
      puts
    end
    
    if failed > 0
      puts "FAILED TESTS:"
      @test_results.select { |r| r[:status] == "FAIL" }.each do |result|
        puts "  - #{result[:command] || result[:controller]}: #{result[:error] || 'Failed'}"
      end
      puts
    end
    
    if missing > 0
      puts "MISSING FILES:"
      @test_results.select { |r| r[:status] == "MISSING" }.each do |result|
        puts "  - #{result[:command] || result[:expected_file] || result[:controller]}"
      end
      puts
    end
    
    puts "=== FUNCTIONALITY STATUS ==="
    
    functionality_score = ((passed + warnings * 0.5) / total_tests * 100).round(1)
    
    puts "Overall functionality score: #{functionality_score}%"
    
    if functionality_score >= 90
      puts "🟢 Excellent - Application is ready for testing"
    elsif functionality_score >= 75
      puts "🟡 Good - Minor issues to address"
    elsif functionality_score >= 50
      puts "🟠 Fair - Several issues need attention"
    else
      puts "🔴 Poor - Major issues need to be resolved"
    end
    
    puts "\n=== NEXT STEPS ==="
    puts "1. Fix any syntax errors in failed files"
    puts "2. Implement missing command files"
    puts "3. Ensure all commands have proper execute methods"
    puts "4. Test actual command execution with WebSocket connections"
    puts "5. Verify database operations work correctly"
  end

  def run_all_tests
    test_command_files
    test_base_command
    test_controllers
    analyze_command_coverage
    generate_detailed_report
  end
end

# Run the command tests
tester = CommandTester.new
tester.run_all_tests