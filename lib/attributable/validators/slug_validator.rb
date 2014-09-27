class SlugValidator < ActiveModel::EachValidator
  SLUG_REGEXP = /\A[a-zA-Z0-9\-]+\Z/
  
  def validate_each(object, attribute, value)
    configuration = { :message => I18n.t("activerecord.errors.messages.slugable") }
    configuration.update(options)
    
    object.errors.add(attribute, configuration[:message]) if value.present? && !value.match(SLUG_REGEXP)
  end
end
