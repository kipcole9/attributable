AttributeNormalizer.configure do |config|

  # Allow entry of differing point types:  hash[:lat => 3, :lon => 5], or array[lat, lon]
  config.normalizers[:geography] = lambda do |value, options|
    return value unless value.present?
    if value.is_a?(Hash)
      lat = value[:lat] || value[:latitude]
      lon = value[:lon] || value[:lng] || value[:longitude]
    elsif value.is_a?(Array)
      lat = value.first
      lon = value.last
    end
    lat && lon ? GeographySerializer.factory.point(lon, lat) : value
  end
  
  # Allow entry of differing point types:  hash[:lat => 3, :lon => 5], or array[lat, lon]
  config.normalizers[:geometry] = lambda do |value, options|
    return value unless value.present?
    if value.is_a?(Hash)
      lat = value[:lat] || value[:latitude]
      lon = value[:lon] || value[:lng] || value[:longitude]
    elsif value.is_a?(Array)
      lat = value.first
      lon = value.last
    end
    lat && lon ? GeometrySerializer.factory.point(lon, lat) : nil
  end
  
  # Allow entry of differing point types:  hash[:lat => 3, :lon => 5], or array[lat, lon]
  config.normalizers[:point] = lambda do |value, options|
    return value unless value.present?
    if value.is_a?(Hash)
      lat = value[:lat] || value[:latitude]
      lon = value[:lon] || value[:lng] || value[:longitude]
    elsif value.is_a?(Array)
      lat = value.first
      lon = value.last
    end
    lat && lon ? "(#{lon.to_f},#{lat.to_f})" : nil
  end
  
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

  config.normalizers[:timestamp] = lambda do |value, options|
    return value unless value.present?
    Chronic.time_class.parse(value.to_s) || Chronic.parse(value) || value
  end  
end if defined?(AttributeNormalizer)