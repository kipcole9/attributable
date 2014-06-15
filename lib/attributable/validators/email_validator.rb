# Based upon http://my.rails-royce.org/2010/07/21/email-validation-in-ruby-on-rails-without-regexp/
# Haxney comment.
class EmailValidator < ActiveModel::EachValidator
  def validate_each(object, attribute, value)
    configuration = { :message => "is invalid" }
    configuration.update(options)
    
    begin
      m = Mail::Address.new(value)
      return m.domain && m.address
    rescue Mail::Field::ParseError => e
      object.errors.add(attribute, configuration[:message]) and false
    end
  end
end
