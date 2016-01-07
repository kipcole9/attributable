module Attributable
  module Normalizer
    class Date
      def self.normalize(value, options = {})
        return value unless value.present?
        return value if value.respond_to?(:acts_like_date?) && value.acts_like_date?
        Date.parse(value)
      end
    end
  end
end