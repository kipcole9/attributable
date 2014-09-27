# Based upon http://joshuawood.net/validating-url-in-ruby-on-rails-3/
# But instead of a regexp let URI.parse() do the heavy lifting - it will 
# raise an exception if it can't parse the URI.
require "addressable/uri"

class UriValidator < ActiveModel::EachValidator
  HTTP_SCHEME = /HTTP(S)?/i
  HTTP_HOST   = /\A(.|[:alum:])+\Z/
  HTTP_PATH   = /\A(.|[:alum:]|\/|_|-)+\Z/
  
  def validate_each(object, attribute, value)
    configuration = { 
      :message_invalid        => I18n.t("activerecord.errors.messages.invalid"), 
      :message_uncontactable  => I18n.t("activerecord.errors.messages.url.uncontactable"),
      :message_invalid_host   => I18n.t("activerecord.errors.messages.url.invalid_host"),
      :message_invalid_path   => I18n.t("activerecord.errors.messages.url.invalid_path") 
    }
    configuration.update(options)
    
    return true if value.nil?     # Presence is a separate validation, not our responsibility
    begin
      uri = Addressable::URI.parse(value)
      unless uri.scheme && uri.host
        object.errors.add(attribute, configuration[:message_invalid])
        return false
      end
    rescue Addressable::URI::InvalidURIError => e
      object.errors.add(attribute, [configuration[:message_invalid], e].join(': '))
      return false
    end
    
    # Because Addressable passes as ok hosts with \n and \t in them!
    unless uri.host.match(HTTP_HOST)
      object.errors.add(attribute, configuration[:message_invalid_host])
      return false
    end
    
    unless uri.path.match(HTTP_PATH)
      object.errors.add(attribute, configuration[:message_invalid_path])
      return false
    end if uri.path.present? 
    
    if configuration[:ping] && uri.scheme.match(HTTP_SCHEME)
      begin
        case Net::HTTP.get_response()
          when Net::HTTPSuccess then true
          when Net::HTTPRedirection then true
          else object.errors.add(attribute, configuration[:message_uncontactable]) && false
        end
      rescue # Recover on DNS failures
        object.errors.add(attribute, configuration[:message_uncontactable]) && false
      end 
    end
  end
end
