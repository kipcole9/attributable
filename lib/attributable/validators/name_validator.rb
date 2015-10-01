module ActiveModel
  module Validations
    class NameValidator < ActiveModel::EachValidator
      NAME_REGEXP = /\A[[:print:]]+\Z/
  
      def validate_each(object, attribute, value)
        configuration = { :message => I18n.t("activerecord.errors.messages.nameable") }
        configuration.update(options)
    
        object.errors.add(attribute, configuration[:message]) if value.present? && !value.match(NAME_REGEXP)
      end
  
      def self.format
        NAME_REGEXP.inspect
      end
    end
  end
end