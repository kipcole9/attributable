require "attributable/version"
require "postgresql/schema"
require "attributable/active_record"
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
  
  class Property
    attr_reader :attribute_type, :access_type
    
    def initialize(model, name, property_type, access_type, template)
      @model          = model
      @name           = name
      @property_type  = property_type
      @access_type    = access_type
      @validators     = template[:validators]
      @normalizers    = template[:normalizers]
    end
    
    def as_json
      {"#{@name}":
        {
          type:         @property_type,
          description:  I18n.t("schema.property.#{@name}")
        }
      }
    end
  end

  module ClassMethods
    const_set(:SUBDOMAIN_REGEXP, /(?:[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]|[A-Za-z0-9])/)
    const_set(:CURRENCY_REGEXP,  /\A\d+??(?:\.\d{0,2})?\Z/)
    const_set(:BINSTRING_REGEXP, /\A[10]*\Z/)
    
    const_set(:ATTRIBUTE_TYPES, {
      :string => {
        :normalizers => [ :strip, :blank ]
      },
      :name => {
        :normalizers => [ :strip, :blank, :squish ],
        :validators => {:name => true}
      },
      :slug => {
        :normalizers => [ :strip, :blank, :squish ],
        :validators => {:slug => true}
      },
      :email => {
        :normalizers => [ :strip, :blank ],
        :validators => {:presence => true, :email => true}
      },
      :password => {
        :normalizers => [ :strip, :blank ],
        :validators => {:presence => true, :password => true}
      },
      :url => {
        :normalizers => [ :strip, :blank ],
        :validators => {:presence => true, :uri => true}
      },
      :uuid => {
        :normalizers => [ :strip, :blank ],
        :validators => {:uuid => true}
      },
      :tag_list => {
        :normalizers => [:tag_list]
      },
      :integer => {
        :normalizers => [ :strip, :blank ],
      },
      :array => {
        :validators => {:array => true}
      },
      :datetime => {
        :normalizers => [ :strip, :blank, :timestamp ],
        :validators => {:timestamp => true}
      },
      :printable => {
        :normalizers => [ :strip, :blank ],
        :validators => {:printable => true}
      },
      :article => {
        :normalizers => [ :strip, :blank ],
        :validators => {:article => true}
      },
      :currency => {
        :normalizers => [ :strip, :blank ],
        :validators => {:format => { :with => CURRENCY_REGEXP }, :numericality => true}
      },
      :subdomain => {
        :validators => {:format => { :with => SUBDOMAIN_REGEXP }}
      },
      :bit_varying => {
        :normalizers => [:varbit],
        :validators => {:format => {:with => BINSTRING_REGEXP }}
      },
      :float    => {},
      :numeric  => {},
      :phone    => {},
      :date     => {},
      :boolean  => {},
      :hstore   => {},
      :geometry => {},
      :geography => {},
      :enum => {}
    })

    def property(*attrs)
      return unless connected? && table_exists?
      generate_attribute_methods unless ancestor && ancestor.attribute_methods_generated?

      options         = attrs.last.is_a?(Hash) ? attrs.pop : {}
      requested_type  = options.delete(:type)
      access_type     = options.delete(:access) || :writeable
      
      attrs.each do |attr| 
        attribute_type = requested_type || type_from_database(attr)
        if template = ATTRIBUTE_TYPES[attribute_type.to_sym]
          define_attribute(attr, attribute_type, access_type, template, options)
          properties[attr] = Property.new(name, attr, attribute_type, access_type, template)
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
    
    def as_json
      properties.values.map(&:as_json)
    end

  private
    # TODO: The Postgres adapter has this (simple_type?), use that instead
    def type_from_database(attr)
      (c = columns_hash[attr.to_s]).present? ? c.cast_type.type : :string
    end
    
  end

  module InstanceMethods
  private

  end
end
