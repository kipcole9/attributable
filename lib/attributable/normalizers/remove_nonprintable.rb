module Attributable
  module Normalizer
    class RemoveNonprintable
      def self.normalize(value, options = {})
        return value unless value.present?
        return value.scan(/[[:print:]]/).join
      end
    end
  end
end

