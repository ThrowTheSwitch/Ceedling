
class ConfigWalkinator
  
  def fetch_value(hash, *keys)
    value = nil
    depth = 0

    # walk into hash & extract value at requested key sequence
    keys.each { |symbol|
      depth += 1
      if (not hash[symbol].nil?)
        hash  = hash[symbol]
        value = hash
      else
        value = nil
        break
      end
    } if !hash.nil?
    
    return {:value => value, :depth => depth}
  end
  
end
