require "attributable/version"
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

  module ClassMethods
    const_set(:SUBDOMAIN_REGEXP, /(?:[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]|[A-Za-z0-9])/)
    const_set(:CURRENCY_REGEXP, /^\d+??(?:\.\d{0,2})?$/)
    
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
      :timestamp => {
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
      :geography => {
        :normalizers => [ :strip, :blank, :geography ],
        :serializer => "GeographySerializer"
      },
      :geometry => {
        :normalizers => [ :strip, :blank, :geometry ],
        :serializer => "GeometrySerializer"
      },
      :point => {
        :normalizer => [ :point ]
      },
      :currency => {
        :normalizers => [ :strip, :blank ],
        :validators => {:format => { :with => CURRENCY_REGEXP }, :numericality => true}
      },
      :subdomain => {
        :validators => {:format => { :with => SUBDOMAIN_REGEXP }}
      },
      :varbit => {
        :normalizers => [:varbit]
      }
      :float    => {},
      :numeric  => {},
      :phone    => {},
      :date     => {},
      :boolean  => {},
      :hstore   => {}
    })

    def attribute(*attrs)
      return unless connected? && table_exists?
      generate_attribute_methods unless ancestor && ancestor.attribute_methods_generated?

      options = attrs.last.is_a?(Hash) ? attrs.pop : {}
      requested_type = options.delete(:type)
      access_type = options.delete(:access) || :writeable
      attrs.each do |attr| 
        attribute_type = requested_type || type_from_database(attr)
        if template = ATTRIBUTE_TYPES[attribute_type.to_sym]
          define_attribute(attr, attribute_type, access_type, template, options)
          getable_attributes[attr] = [attribute_type, access_type]
        else
          raise ArgumentError, "#{attr.to_s}: unknown attribute type: '#{attribute_type}': #{options.inspect}"
        end
      end
    end
    alias :attributes :attribute

    def define_attribute(attr, type, access, template, options = {})
      normalize_attribute attr, :with => template[:normalizers] if template[:normalizers]
      validates attr, (template[:validators] || {}).merge(options) if template[:validators].present? || options.any?
      serialize attr, template[:serializer].constantize if template[:serializer]
    end

    def getable_attributes
      @getable_attributes ||= ancestor ? ancestor.getable_attributes.dup : {}
    end

    def setable_attributes
      @setable_attribtues ||= getable_attributes.select {|name, attrs| attrs.last == :writeable}
    end

    def readonly_attributes
      @readable_attributes ||= getable_attributes.select {|name, attrs| attrs.last == :readonly}     
    end

    def attribute_names
      @attribute_names ||= getable_attributes.stringify_keys.keys
    end

  private
    # TODO: The Postgres adapter has this (simple_type?), use that instead
    def type_from_database(attr)
      type = columns_hash[attr.to_s].present? ? columns_hash[attr.to_s].sql_type : :string
      case type
      when /character/, 'text'
        :string
      when /timestamp/
        :timestamp
      when 'double precision'
        :float
      when 'integer', 'smallint', 'bigint'
        :integer
      when /bit/i
        :varbit  
      else
        if self.connection.enum_types.include?(type)
          :string
        else
          type.to_sym
        end
      end
    end

  end

  module InstanceMethods
  private

  end
end
