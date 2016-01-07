module Attributable
  module Normalizer
    class Timestamp
      def self.normalize(value, options = {})
        return value unless value.present?
        return value if value.respond_to?(:acts_like_time?) && value.acts_like_time?
        DateTime.parse(value).in_time_zone
      end
    end
  end
end