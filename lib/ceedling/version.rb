# @private
module Ceedling
  module Version

    def version_grabber(filename, prefix)
      a = [0,0,0]
      File.readlines(filename) do |line|
        ["VERSION_MAJOR", "VERSION_MINOR", "VERSION_BUILD"].each_with_index do |field, i|
          m = line.match(/#{prefix}_#{field}\s+(\d+)/)
          a[i] = m[1] unless (m.nil?)
        end
      end
      a.join(".")
    end

    # @private
    GEM = "0.29.0"
    # @private
    CEEDLING = GEM
    # @private
    CEXCEPTION = version_grabber(File.join(CEXCEPTION_LIB_PATH,CEXCEPTION_H_FILE), "CEXCEPTION")
    # @private
    CMOCK = version_grabber( File.join(CMOCK_LIB_PATH,CMOCK_H_FILE), "CMOCK")
    # @private
    UNITY = version_grabber( File.join(UNITY_LIB_PATH,UNITY_H_FILE), "UNITY")
  end
end
