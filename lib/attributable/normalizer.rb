AttributeNormalizer.configure do |config|

  # Parse a delimited list into an array of structs
  require 'csv'
  config.normalizers[:tag_list] = lambda do |value, options|
    return value unless value.present?
    return value if value.is_a?(Array)
    list = CSV.parse(value).first
    list.collect! do |t| 
      t.try(:gsub,/[[:cntrl:]]/,'').try(:strip)
    end.compact if list
    list
  end
    
  config.normalizers[:array] = lambda do |value, options|
    return value unless value.present?
    return value if value.is_a?(Array)
    list = CSV.parse(value).first
    list.collect! do |t| 
      t.try(:gsub,/[[:cntrl:]]/,'').try(:strip)
    end.compact if list
    list
  end
  
  config.normalizers[:varbit] = lambda do |value, options|
    return value unless value.present?
    return value if value.is_a?(String)
    case value.class.to_s
    when 'Fixnum', 'Integer', 'Numeric', 'BigDecimal', 'Bignum'
      value.to_s(2)
    when 'Float'
      value.to_i.to_s(2)
    else
      value
    end
  end

  config.normalizers[:timestamp] = lambda do |value, options|
    return value unless value.present?
    Chronic.time_class.parse(value.to_s) || Chronic.parse(value) || value
  end  
end if defined?(AttributeNormalizer)