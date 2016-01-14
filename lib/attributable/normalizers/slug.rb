module Attributable
  module Normalizer
    class Slug
      LIMIT = 200
      def self.normalize(value, options = {})
        return value unless value.present?
        return value.truncate(LIMIT)
      end
    end
  end
end