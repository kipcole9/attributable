# TODO: Not yet implementing enum and object
module Attributable
  class Property
    JSON_SCHEMA_FORMAT_TYPES = [:email, :uuid, :uri, :datetime]
    attr_reader :model_name, :name, :property_type, :access_type, :template, :validators, :normalizers
    attr_reader :schema_type, :schema_format, :subtype, :schema_pattern
    
    def initialize(model_name, name, property_type, access_type, template, subtype = nil, subtype_template = nil)
      @model_name     = model_name
      @name           = name
      @property_type  = property_type
      @access_type    = access_type
      @validators     = template[:validators]
      @normalizers    = template[:normalizers]
      @schema_type    = template[:json_schema_type]
      @schema_format  = template[:json_schema_format]
      @schema_pattern = remove_leading_and_trailing_slashes(template[:json_schema_pattern])
            
      # if the type is array then we need to also process the subtype
      if subtype
        @subtype = Property.new(model_name, name, subtype, access_type, subtype_template)
      end
    end
    
    # Output a hash that will convert to valid json-schema.  Properties may have the following elements:
    #   title
    #   description
    #   default
    #   format
    #   multipleOf
    #   maximum, exclusiveMaximum
    #   minimum, execlusiveMinimum
    #   maxLength
    #   minLength
    #
    # For arrays also can include
    #   minIems
    #   maxItems
    def as_json(options = {})
      json = Hash.new
      json[name]                        = {}
      json[name][:type]                 = schema_type
      json[name][:description]          = I18n.t("schema.property.#{name}")
      json[name][:format]               = format                if format
      json[name][:pattern]              = pattern               if pattern && !format
      json[name][:enum]                 = enum_definition       if property_type == :enum
      json[name][:default]              = default_value         if has_default_value?
      json[name][:max_length]           = max_length            if max_length
      json[name][:min_length]           = min_length            if min_length
      json[name][:maximum]              = maximum               if maximum
      json[name][:minimum]              = minimum               if minimum
      json[name][:exclusive_maximum]    = exclusive_maximum     if exclusive_maximum
      json[name][:exclusive_minimum]    = exclusive_minimum     if exclusive_minimum
      json[name][:items]                = subtype.as_json(options)[name].reject{|k,v| k == :description} if subtype
      json
    end
    
    def format
      return schema_format if schema_format
      
      # Only regexps for pattern
      formats = validator_formats.delete_if{|f| f.is_a? Regexp}
      
      # Add custom formats for integers
      formats << "int16" if column.sql_type == "smallint"
      formats << "int32" if column.sql_type == "integer"
      formats << "int64" if column.sql_type == "bigint"
      formats << "int16" if column.sql_type == "smallint"
      
      formats.first
    end
    
    def pattern
      return schema_pattern if schema_pattern

      formats = validator_formats.delete_if{|f| !f.is_a?(Regexp)}
      
      # Extract format from any customized formatters and add them to the list
      format_validator = validator_for_property(ActiveModel::Validations::FormatValidator)
      formats << format_validator.options[:with] if format_validator
      
      # Take the first format and remove the leading and trailing '/'
      formats.any? ? remove_leading_and_trailing_slashes(formats.first) : nil
    end
    
    def validator_formats
      @formats ||= validators.map do |key, value| 
        "ActiveModel::Validations::#{key.to_s.capitalize}Validator".constantize.format
      end.compact
      @formats
    end
    
    def required?
      validators[:presence]
    end
    
    def enum_definition
      ActiveRecord::Base.connection.enum_values(column.sql_type)
    end
    
    def column
      @column ||= model_name.constantize.columns_hash[name.to_s]
    end
    
  private
  
    def validator_for_property(validator)
      model_name.constantize.validators.select do |a| 
        a.attributes.include?(name.to_sym) && a.class == validator
      end.first
    end
  
    def remove_leading_and_trailing_slashes(format)
      return nil unless format.present?
      return format unless format.is_a? Regexp
      format.inspect.sub(/^\//,'').sub(/\/$/,'')
    end
    
    def default_value
      column.default
    end
    
    def has_default_value?
      column.has_default?
    end
    
    # This is the database limit -> need to also check validators limits
    def max_length
      return unless schema_type == :string
      if length_validator = validator_for_property(ActiveModel::Validations::LengthValidator)
        max = length_validator.options[:maximum] || length_validator.options[:in].try(:last) || length_validator.options[:is] 
      end
      max || column.limit
    end
    
    def min_length
      if length_validator = validator_for_property(ActiveModel::Validations::LengthValidator)
        min = length_validator.options[:minimum] || length_validator.options[:in].try(:first) || length_validator.options[:is] 
      end
      min
    end
    
    def maximum
      if numeric_validator = validator_for_property(ActiveModel::Validations::NumericalityValidator)
        maximum = numeric_validator.options[:greater_than] || numeric_validator.options[:greater_than_or_equal_to] || numeric_validator.options[:equal_to] 
      end
      maximum
    end
    
    def minimum
      if numeric_validator = validator_for_property(ActiveModel::Validations::NumericalityValidator)
        minimum = numeric_validator.options[:less_than] || numeric_validator.options[:less_than_or_equal_to] || numeric_validator.options[:equal_to] 
      end
      minimum      
    end

    def exclusive_minimum
      if numeric_validator = validator_for_property(ActiveModel::Validations::NumericalityValidator)
        return true if numeric_validator.options[:greater_than]
      end
      false 
    end
        
    def exclusive_maximum
      if numeric_validator = validator_for_property(ActiveModel::Validations::NumericalityValidator)
        return true if numeric_validator.options[:less_than]
      end
      false 
    end

  end
  
end