require 'csv'
  
module Attributable
  module Normalizer
    class TagList
      def self.normalize(value, options = {})
        return value unless value.present?

        # Parse a string into an array if thats what we've got
        if value.is_a?(String)
          list = CSV.parse(value).first
          tags = list.collect do |t| 
            t.try(:gsub,/[[:cntrl:]]/,'').try(:strip)
          end.compact if list
        end

        # Ensure we have an array
        tags ||= value || []

        # Normalize tags by removing any leading '#'
        # and stringify anthing we have
        tags.map!{|t| t.to_s.sub(/\A#/,'') }
        tags
      end
    end
  end
end