module Attributable
  module Normalizer
    class Varbit
      def self.normalize(value, options = {})
        return value unless value.present?
        return value if value.is_a?(String)
        case value.class.to_s
        when 'Fixnum', 'Integer', 'Numeric', 'BigDecimal', 'Bignum'
          value.to_s(2)
        when 'Float'
          value.to_i.to_s(2)
        else
          value
        end
      end
    end
  end
end