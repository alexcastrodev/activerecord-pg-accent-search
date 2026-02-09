#!/usr/bin/env ruby
# run_all.rb
require 'thread'

# List of files to run
files = Dir.glob('*.rb').reject { |f| f == File.basename(__FILE__) }.sort

puts "[INFO] Starting parallel execution of #{files.count} test files..."
puts "--------------------------------------------------"

threads = files.map do |filename|
  Thread.new do
    start_time = Time.now
    output = `ruby #{filename} 2>&1`
    duration = Time.now - start_time
    success = $?.success?
    
    { 
      filename: filename, 
      success: success, 
      output: output,
      duration: duration.round(2)
    }
  end
end

results = threads.map(&:value)

failures = []

results.each do |result|
  puts "--------------------------------------------------"
  puts "[INFO] Output for #{result[:filename]} (took #{result[:duration]}s):"
  puts result[:output]
  
  if result[:success]
    puts "[PASS] #{result[:filename]}"
  else
    puts "[FAIL] #{result[:filename]}"
    failures << result[:filename]
  end
end

puts "--------------------------------------------------"
if failures.empty?
  puts "[SUCCESS] All tests passed!"
  exit 0
else
  puts "[ERROR] The following #{failures.count} files failed:"
  failures.each { |f| puts " - #{f}" }
  exit 1
end
