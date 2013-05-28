PROJECT_CEEDLING_ROOT = "vendor/ceedling"
load "#{PROJECT_CEEDLING_ROOT}/lib/ceedling/rakefile.rb"

task :default => %w[ test:all release ]

# Dummy task to ensure that the SERIAL_PORT environment variable is set.
# It can be set on the command line as follows:
#   $ rake SERIAL_PORT=[serial port name]
task :serial_port do
  unless ENV['SERIAL_PORT']
    raise "SERIAL_PORT is not defined in the environment!"
  end
end

desc "Convert the output binary to a hex file for programming to the Arduino"
task :convert => :release do
  bin_file = "build/release/#{RELEASE_BUILD_OUTPUT}.bin"
  hex_file = "build/release/#{RELEASE_BUILD_OUTPUT}.hex"
  cmd = "#{ENV['OBJCOPY']} -O ihex -R .eeprom #{bin_file} #{hex_file}"
  puts cmd
  sh cmd
end

desc "Program the Arduino over the serial port."
task :program => [:convert, :serial_port] do
  hex_file = "build/release/#{RELEASE_BUILD_OUTPUT}.hex"
  cmd = "avrdude -F -V -c arduino -p #{ENV['MCU']} -P #{ENV['SERIAL_PORT']} -b 115200 -U flash:w:#{hex_file}"
  puts cmd
  sh cmd
end
