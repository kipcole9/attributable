require "attributable/version"
require "attributable/railtie"
require "postgresql/schema"
require "attributable/active_record"
require "attributable/property"
require "attribute_normalizer"
require "attributable/normalizer"
require "attributable/validators/email_validator"
require "attributable/validators/name_validator"
require "attributable/validators/email_validator"
require "attributable/validators/password_validator"
require "attributable/validators/printable_validator"
require "attributable/validators/slug_validator"
require "attributable/validators/timestamp_validator"
require "attributable/validators/uri_validator"
require "attributable/validators/uuid_validator"

module Attributable
  def self.included(base)
    base.instance_eval do
      include InstanceMethods
      extend ClassMethods
    end
  end
  
  module ClassMethods
    # types: array, boolean, integer, number, null, object, string
    # formats: date-time, email, hostname, ipv4, ipv6, uri
    # extended formats:  date, int16, int32, int64
    
    const_set(:SUBDOMAIN_REGEXP, /(?:[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]|[A-Za-z0-9])/)
    const_set(:CURRENCY_REGEXP,  /\A\d+??(?:\.\d{0,2})?\Z/)
    const_set(:BINSTRING_REGEXP, /\A[10]*\Z/)
    
    const_set(:ATTRIBUTE_TYPES, {
      :string => {
        :normalizers => [ :strip, :blank ],
        :validators => {},
        :json_schema_type => :string
      },
      :name => {
        :normalizers => [ :strip, :blank, :squish ],
        :validators => {:name => true},
        :json_schema_type => :string
      },
      :slug => {
        :normalizers => [ :strip, :blank, :squish ],
        :validators => {:slug => true},
        :json_schema_type => :string
      },
      :email => {
        :normalizers => [ :strip, :blank ],
        :validators => {:presence => true, :email => true},
        :json_schema_type => :string,
        :json_schema_format => :email
      },
      :password => {
        :normalizers => [ :strip, :blank ],
        :validators => {:presence => true, :password => true},
        :json_schema_type => :string
      },
      :url => {
        :normalizers => [ :strip, :blank ],
        :validators => {:presence => true, :uri => true},
        :json_schema_type => :string,
        :json_schema_format => :uri
      },
      :uuid => {
        :normalizers => [ :strip, :blank ],
        :validators => {:uuid => true},
        :json_schema_type => :string,
        :json_schema_format => :uuid
      },
      :tag_list => {
        :normalizers => [:tag_list],
        :validators => {},
        :json_schema_type => :array
      },
      :integer => {
        :normalizers => [ :strip, :blank ],
        :validators => {:numericality => { only_integer: true, allow_blank: true }},
        :json_schema_type => :integer
      },
      :array => {
        :validators => {:array => true}
      },
      :date => {
        :validators => {},     
        :normalizers => [ :strip, :blank, :date ],
        :json_schema_type => :string,
        :json_schema_format => :date
      },
      :datetime => {
        :normalizers => [ :strip, :blank, :timestamp ],
        :validators => {:timestamp => true},
        :json_schema_type => :string,
        :json_schema_format => 'date-time'
      },
      :printable => {
        :normalizers => [ :strip, :blank ],
        :validators => {:printable => true},
        :json_schema_type => :string,
        :json_schema_pattern => ActiveModel::Validations::PrintableValidator.format
      },
      :article => {
        :normalizers => [ :strip, :blank ],
        :validators => {:article => true},
        :json_schema_type => :string,
        :json_schema_pattern => ActiveModel::Validations::PrintableValidator.format
      },
      :currency => {
        :normalizers => [ :strip, :blank ],
        :validators => {:format => { :with => CURRENCY_REGEXP }},
        :json_schema_type => :number,
        :json_schema_pattern => CURRENCY_REGEXP
      },
      :subdomain => {
        :validators => {:format => { :with => SUBDOMAIN_REGEXP }},
        :json_schema_type => :string,
        :json_schema_pattern => CURRENCY_REGEXP
      },
      :bit_varying => {
        :normalizers => [:varbit],
        :validators => {:format => {:with => BINSTRING_REGEXP }}
      },
      :float      => {
        :validators => {:numericality => {:allow_blank => true}},
        :json_schema_type => :number,
        :json_schema_format => :float
      },
      :numeric    => {
        :validators => {:numericality => {:allow_blank => true}},
        :json_schema_type => :number,
      },
      :boolean    => {
        :json_schema_type => :boolean
      },      
      :phone      => {
        :validators => {:phone => true}
      },
      :enum       => {
        :validators => {},
        :json_schema_type => :string
      },
      :hstore     => {:validators => {}},
      :geometry   => {:validators => {}},
      :geography  => {:validators => {}}
    })

    def property(*attrs)
      return unless connected? && table_exists?
      generate_attribute_methods unless ancestor && ancestor.attribute_methods_generated?

      options = attrs.last.is_a?(Hash) ? attrs.pop : {}
      access_type ||= options.delete(:access) || :writeable
      requested_type ||= options.delete(:type)
      
      attrs.each do |attr| 
        attribute_type = requested_type || type_from_database(attr)
        if template = ATTRIBUTE_TYPES[attribute_type.to_sym]
          define_attribute(attr, attribute_type, access_type, template, options)
          properties[attr] = Property.new(name, attr, attribute_type, access_type, template, 
            subtype(attr), subtype_template(attr))
        else
          raise ArgumentError, "#{attr.to_s}: unknown attribute type: '#{attribute_type}': #{options.inspect}"
        end
      end
    end
    
    def properties
      @properities ||= ancestor ? ancestor.properties.dup : {}
    end

    def define_attribute(attr, type, access, template, options = {})
      normalize_attribute attr, :with => template[:normalizers] if template[:normalizers]
      validates attr, (template[:validators] || {}).merge(options) if template[:validators].present? || options.any?
      serialize attr, template[:serializer].constantize if template[:serializer]
    end

    def setable_properties
      @setable_properties ||= properties.select {|name, attrs| attrs.access_type == :writeable}
    end

    def readonly_properties
      @readable_properties ||= properties.select {|name, attrs| attrs.access_type == :readonly}     
    end

    def property_names
      @property_names ||= properties.stringify_keys.keys
    end
    
    def as_json(options = {})
      schema = Hash.new
      schema['$schema']     = "http://json-schema.org/draft-04/schema#"
      schema[:title]        = name.capitalize
      schema[:description]  = I18n.t("schema.table.#{table_name}")
      schema[:type]         = 'object'
      schema[:properties]   = properties_hash
      schema[:required]     = required_properties if required_properties.any?
      schema
    end

  private
    def properties_hash
      @properties_hash ||= properties.values.map(&:as_json).inject({}) do |hash, value| 
        k = value.keys.first
        v = value.values.first
        hash[k] = v
        hash
      end
    end
     
    # TODO: The Postgres adapter has this (simple_type?), use that instead
    def type_from_database(attr)
      (c = columns_hash[attr.to_s]).present? ? c.cast_type.type : :string
    end
    
    def required_properties
      properties.values.map{|p| p.required? ? p.name : nil}.compact
    end
    
    def subtype(attribute)
      if columns_hash[attribute.to_s] && columns_hash[attribute.to_s].array
        subtype = columns_hash[attribute.to_s].cast_type.subtype
        subtype.class.name.split('::').last.downcase.to_sym
      end
    end
    
    def subtype_template(attribute)
      ATTRIBUTE_TYPES[subtype(attribute).to_sym] if subtype(attribute)
    end
    
  end

  module InstanceMethods
  private

  end
end
