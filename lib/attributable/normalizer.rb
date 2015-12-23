AttributeNormalizer.configure do |config|

  # Parse a delimited list into an array of structs
  require 'csv'
  config.normalizers[:tag_list] = lambda do |value, options|
    return value unless value.present?

    # Parse a string into an array if thats what we've got
    if value.is_a?(String)
      list = CSV.parse(value).first
      tags = list.collect do |t| 
        t.try(:gsub,/[[:cntrl:]]/,'').try(:strip)
      end.compact if list
    end
    
    # Ensure we have an array
    tags ||= value || []
    
    # Normalize tags by removing any leading '#'
    # and stringify anthing we have
    tags.map!{|t| t.to_s.sub(/\A#/,'') }
    tags
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
    return value if value.respond_to?(:acts_like_time?) && value.acts_like_time?
    DateTime.parse(value).in_time_zone
  end
  
  config.normalizers[:date] = lambda do |value, options|
    return value unless value.present?
    return value if value.respond_to?(:acts_like_date?) && value.acts_like_date?
    Date.parse(value)
  end  
end if defined?(AttributeNormalizer)