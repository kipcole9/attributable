module ActiveModel
  module Validations
    class TimestampValidator < ActiveModel::EachValidator
      VALID_TIME_CLASSES = [Time, ActiveSupport::TimeWithZone]
  
      # Note this is of limited (no?) use because AR will ignore timestamps it doesn't understand
      # and the attribute will be set to nil
      def validate_each(object, attribute, value)
        configuration = { :message => I18n.t('activerecord.errors.messages.invalid')}
        configuration.update(options)
  
        object.errors.add(attribute, configuration[:message]) if invalid_timestamp(value)
      end
  
    private
      def invalid_timestamp(value)
        value.present? && !VALID_TIME_CLASSES.include?(value.class)
      end
      
      def self.format
        nil
      end
    end
  end
end