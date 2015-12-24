require 'twitter-text'

module ActiveModel
  module Validations
    class TagListValidator < ActiveModel::EachValidator
      # Alpha first character, alphanumeric for subsequent characters
      # no whitespace or punctuation or unprintable characters
      TAG_REGEXP = /(#{::Twitter::Regex::HASHTAG_ALPHANUMERIC}*#{::Twitter::Regex::HASHTAG_ALPHA}#{::Twitter::Regex::HASHTAG_ALPHANUMERIC}*)/io
      
      def validate_each(object, attribute, value)
        configuration = { message: I18n.t('activerecord.errors.messages.taglist')}
        configuration.update(options)
        invalid_tags = []
    
        return if value.nil?
        object.errors.add(attribute, configuration[:message]) and return unless value.respond_to?(:each)
        
        value.each do |v|
          invalid_tags << v unless v.is_a?(String) &&  v.match(TAG_REGEXP)
        end

        object.errors.add(attribute, invalid_tag_message(invalid_tags, configuration)) if invalid_tags.any?
      end
      
      def invalid_tag_message(invalid_tags, configuration)
        "#{configuration[:message]}: #{invalid_tags.inspect}"
      end
      
      def self.format
        TAG_REGEXP
      end
    end
  end
end
