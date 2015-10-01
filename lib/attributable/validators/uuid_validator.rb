module ActiveModel
  module Validations
    class UuidValidator < ActiveModel::EachValidator
      UUID_REGEXP = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
  
      # TODO: Move to i18n message format
      def validate_each(object, attribute, value)
        configuration = { :message => "is invalid" }
        configuration.update(options)
    
        # UUID is also used to associations and we could have a record here rather than a UUID
        return if value && value.class.respond_to?(:descends_from_active_record?)
    
        object.errors.add(attribute, configuration[:message]) if value.present? && !value.match(UUID_REGEXP)
      end
  
      def self.format
        UUID_REGEXP
      end
    end
  end
end