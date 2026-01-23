
class Partializer
  
  def test_partial?(type)
    return !(type.to_s.include?('mock'))
  end

end