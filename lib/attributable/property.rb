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
      @validators     = template[:validators].dup
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
    def as_json_schema(options = {})
      json = Hash.new
      json[name]                        = {}
      json[name][:type]                 = schema_type
      json[name][:description]          = I18n.t("schema.property.#{name}")
      json[name][:format]               = format                if format
      json[name][:pattern]              = pattern               if pattern && !format && schema_type != :array
      json[name][:enum]                 = enum_definition       if property_type == :enum
      json[name][:default]              = default_value         if has_default_value?     
      json[name][:max_length]           = max_length            if max_length
      json[name][:min_length]           = min_length            if min_length
      json[name][:maximum]              = maximum               if maximum
      json[name][:minimum]              = minimum               if minimum
      json[name][:exclusive_maximum]    = exclusive_maximum     if exclusive_maximum
      json[name][:exclusive_minimum]    = exclusive_minimum     if exclusive_minimum
      json[name][:readonly]             = true                  if readonly
      json[name][:items]                = subtype_json          if subtype
      json[name].merge!(object_json)                            if schema_type == :object
      json
    end
    
    def format
      return schema_format if schema_format
      
      # Only regexps for pattern
      formats = validator_formats.delete_if{|f| f.is_a? Regexp}
      
      # Add custom formats for integers
      if column.present?
        formats << "int16" if column.sql_type == "smallint"
        formats << "int32" if column.sql_type == "integer"
        formats << "int64" if column.sql_type == "bigint"
        formats << "int16" if column.sql_type == "smallint"
      end
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
        "ActiveModel::Validations::#{key.to_s.classify}Validator".constantize.format rescue nil
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
      format.to_s
    end
    
    def default_value
      column.default || column.default_function
    end
    
    # Default value may be nil (as Id column) but
    # thats because there is a default function
    # so we dont supply a default in the json in that case
    def has_default_value?
      return nil unless column
      column.has_default? || column.default_function
    end
    
    def subtype_json(options = {})
      subtype.as_json_schema.values.first.reject{|k,v| k == :description}
    end
    
    def object_json
      ActiveRecord::Base.connection.type_map.lookup(column.type.to_s).class.as_json_schema
    end
    
    def max_length
      return unless schema_type == :string
      if length_validator = validator_for_property(ActiveModel::Validations::LengthValidator)
        max = length_validator.options[:maximum] || length_validator.options[:in].try(:last) || length_validator.options[:is] 
      end
      max || column.try(:limit)
    end
    
    def min_length
      return unless schema_type == :string
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
    
    def readonly
      access_type == :readonly
    end

  end
  
end