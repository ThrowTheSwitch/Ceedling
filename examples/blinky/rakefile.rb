PROJECT_CEEDLING_ROOT = "vendor/ceedling"
load "#{PROJECT_CEEDLING_ROOT}/lib/rakefile.rb"

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
  sh "#{ENV['objcopy']} -O ihex -R .eeprom build\\release\\#{RELEASE_BUILD_OUTPUT}.bin build\\release\\#{RELEASE_BUILD_OUTPUT}.hex"
end

desc "Program the Arduino over the serial port."
task :program => [:convert, :serial_port] do
  sh "avrdude -F -V -c arduino -p #{ENV['MCU']} -P #{ENV['SERIAL_PORT']} -b 115200 -U flash:w:build\\release\\#{RELEASE_BUILD_OUTPUT}.hex"
end