class PrintableValidator < ActiveModel::EachValidator
  PRINTABLE_REGEXP = /\A[[:space:][:print:]]+\Z/
  
  def validate_each(object, attribute, value)
    configuration = { :message => I18n.t('activerecord.errors.messages.printable')}
    configuration.update(options)
    
    object.errors.add(attribute, configuration[:message]) if value.present? && !value.match(PRINTABLE_REGEXP)
  end
end
