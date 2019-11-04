
# @private
module Ceedling
  module Version
    { "UNITY" => File.join("vendor","unity","src","unity.h"),
      "CMOCK" => File.join("vendor","cmock","src","cmock.h"),
      "CEXCEPTION" => File.join("vendor","c_exception","lib","CException.h") 
    }.each_pair do |name, path|
      # Check for local or global version of vendor directory in order to look up versions
      path1 = File.expand_path( File.join("..","..",path) )
      path2 = File.expand_path( File.join(File.dirname(__FILE__),"..","..",path) )
      filename = if (File.exists?(path1))
        path1
      elsif (File.exists?(path2))
        path2
      else
        module_eval("#{name} = 'unknown'")
        continue
      end

      # Actually look up the versions
      a = [0,0,0]
      File.readlines(filename).each do |line|
        ["VERSION_MAJOR", "VERSION_MINOR", "VERSION_BUILD"].each_with_index do |field, i|
          m = line.match(/#{name}_#{field}\s+(\d+)/)
          a[i] = m[1] unless (m.nil?)
        end
      end

      # splat it to return the final value
      eval("#{name} = '#{a.join(".")}'")
    end

    GEM = "0.29.1"
    CEEDLING = GEM
  end
end
