# TODO: Phone number validation is very brute force, looping through all territories to see if one matches
module ActiveModel
  module Validations
    class PhoneValidator < ActiveModel::EachValidator

      def validate_each(object, attribute, value)
        configuration = { :message => I18n.t('activerecord.errors.messages.phonenumber_is_invalid')}
        configuration.update(options)
    
        object.errors.add(attribute, configuration[:message]) if value.present? && !validate_phone_number(value)
      end
      
      def validate_phone_number(number)
        return true if GlobalPhone.validate(number)
         territories.each do |territory|
          return true if GlobalPhone.validate(number, territory)
        end
        false
      end
  
      def territories
        @@territories ||= GlobalPhone.db.regions.map{|r| r.territories}.flatten.map{|t| t.name.downcase.to_sym}.uniq.sort
      end
      
      def self.format
        :phone
      end
    end
  end
end