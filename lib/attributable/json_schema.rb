module Attributable
  module JsonSchema
    JSON_SCHEMA_NAME = "http://json-schema.org/draft-04/schema#"
  
    def self.included(base)
      base.extend ClassMethods
    end
  
    module ClassMethods
    
      # options[:case] can be 'camelcase' or 'camelback'
      def as_json_schema(options = {})
        schema = Hash.new
        schema[:'$schema']    = JSON_SCHEMA_NAME
        schema[:id]           = name.downcase
        schema[:title]        = name.underscore.humanize
        schema[:description]  = I18n.t("schema.table.#{table_name}")
        schema[:type]         = 'object'
        schema[:properties]   = properties_as_json_schema
        schema[:required]     = required_properties if required_properties.any?
        options[:case] ? schema.send("to_#{options[:case]}_keys") : schema
      end

    private
      def properties_as_json_schema
        @properties_as_json ||= properties.inject({}) {|hash, (k, v)| hash.merge(v.as_json_schema)}
      end

      def required_properties
        properties.values.map{|p| p.required? ? p.name : nil}.compact
      end
      
      def json_schema_name
        JSON_SCHEMA_NAME
      end

    end
  end
end