
class ConfigWalkinator
  
  def fetch_value(hash, *keys)
    value = nil
    depth = 0

    # walk into hash & extract value at requested key sequence
    keys.each do |symbol|
      depth += 1
      if (not hash[symbol].nil?)
        hash  = hash[symbol]
        value = hash
      else
        value = nil
        break
      end
    end
    
    return {:value => value, :depth => depth}
  end
  
end
