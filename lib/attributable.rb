require "attributable/version"
require "attributable/railtie"
require "postgresql/schema"
require "attributable/active_record"
require "attributable/property"
require "attributable/normalizer"
Dir["#{File.dirname(__FILE__)}/attributable/validators/*.rb"].each {|f| require f}
require "attributable/json_schema"

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
        :normalizers => [ :strip, :blank, :squish, :name ],
        :validators => {:name => true},
        :json_schema_type => :string,
        :json_schema_pattern => ActiveModel::Validations::NameValidator.format
      },
      :slug => {
        :normalizers => [ :strip, :blank, :squish, :slug ],
        :validators => {:slug => true},
        :json_schema_type => :string,
        :json_schema_pattern => ActiveModel::Validations::SlugValidator.format
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
        :json_schema_type => :string,
        :json_schema_pattern => ActiveModel::Validations::PasswordValidator.format
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
        :validators => {tag_list: true},
        :json_schema_type => :array,
        :json_schema_pattern => ActiveModel::Validations::TagListValidator.format
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
        :normalizers => [ :strip, :blank, :remove_nonprintable ],
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
        :validators => {:format => {:with => BINSTRING_REGEXP }},
        :json_schema_type => :string
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
      :hstore     => {:validators => {}
      },
      :geometry   => {
        :json_schema_type => :object,
        :validators => {}
      },
      :geography  => {
        :json_schema_type => :object,
        :validators => {}
      }
    })

    def property(*attrs)
      return unless connected? && table_exists?
      generate_attribute_methods unless ancestor && ancestor.attribute_methods_generated?

      options = attrs.last.is_a?(Hash) ? attrs.pop : {}
      access_type ||= options.delete(:access) || :writeable
      requested_type ||= options.delete(:type)
      
      attrs.each do |attr| 
        attribute_type = requested_type || type_from_database(attr)
        if template = ATTRIBUTE_TYPES[attribute_type.to_sym].deep_dup
          template[:validators] = (template[:validators] || {}).merge(options)
          define_property(attr, attribute_type, access_type, template, options)
          properties[attr] = Property.new(name, attr, attribute_type, access_type, template, 
            subtype(attr), subtype_template(attr, attribute_type))
        else
          raise ArgumentError, "#{attr.to_s}: unknown attribute type: '#{attribute_type}': #{options.inspect}"
        end
      end
    end
    
    def properties
      @properities ||= ancestor ? ancestor.properties.dup : {}
    end

    def define_property(attr, type, access, template, options = {})
      normalize_attribute attr, :with => template[:normalizers] if template[:normalizers]
      validates attr, template[:validators]                     if template[:validators].any?
      serialize attr, template[:serializer].constantize         if template[:serializer]
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

  private
    def type_from_database(attr)
      (c = columns_hash[attr.to_s]).present? ? c.type : :string
    end

    def subtype(attribute)
      column = columns_hash[attribute.to_s]
      column.type if column && column.array?
    end
    
    def subtype_template(attribute, attribute_type)
      if subtype(attribute)
        subtype = ATTRIBUTE_TYPES[subtype(attribute).to_sym].dup
        subtype[:json_schema_pattern] = ATTRIBUTE_TYPES[attribute_type.to_sym][:json_schema_pattern]
        subtype[:json_schema_format] = ATTRIBUTE_TYPES[attribute_type.to_sym][:json_schema_format]
      end
      subtype
    end
    
  end

  module InstanceMethods
  private

  end
end
