module ActiveModel
  module Validations
    class PasswordValidator < ActiveModel::EachValidator
      PASSWORD_REGEXP = /\A(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?!.*\s).*\Z/
  
      def validate_each(object, attribute, value)
        configuration = { :message => "is invalid" }
        configuration.update(options)
    
        object.errors.add(attribute, configuration[:message]) if value.present? && !value.match(PASSWORD_REGEXP)
      end
  
      def self.format
        PASSWORD_REGEXP.to_s
      end
    end
  end
end