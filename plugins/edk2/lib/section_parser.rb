FILTERS = {
   comment: /\#.*/,
   preprocessor: /^\s*\!\w+\s.*/,
   bracket: /\{.*?\}/m
}


def GetSectionContents(filename, section_pattern, filters=nil)
   if File.exists?(filename)
      data = File.read(filename)
   else
      raise "ERROR: \"#{filename}\" does not exist."
   end

   if not filters.nil?
      filters.each do |filter|
         data = data.gsub(filter, "")
      end
   end

   section_header_pattern = /\[.+\]/
   section_contents = []
   in_section = false

   data.lines().each do |line|
      line = line.strip()
      unless line.empty?
         if line =~ section_header_pattern
            if line =~ section_pattern
               in_section = true
            else
               in_section = false
            end
         elsif in_section
            section_contents << line
         end
      end
   end

   return section_contents
end
