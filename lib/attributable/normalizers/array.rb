require 'csv'

module Attributable
  module Normalizer
    class Array
      def self.normalize(value, options = {})
        return value unless value.present?
        return value if value.is_a?(Array)
        list = CSV.parse(value).first
        list.collect! do |t| 
          t.try(:gsub,/[[:cntrl:]]/,'').try(:strip)
        end.compact if list
        list
      end
    end
  end
end