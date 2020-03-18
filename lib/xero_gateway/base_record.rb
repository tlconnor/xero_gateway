module XeroGateway
  class BaseRecord
    class UnsupportedAttributeType < StandardError; end

    class_attribute :element_name
    class_attribute :attribute_definitions
    class_attribute :attribute_definitions_readonly

    class << self
      def attributes(hash)
        hash.each do |k, v|
          attribute k, v
        end
      end

      def attribute(name, value, nested = false)
        self.attribute_definitions ||= {}
        self.attribute_definitions[name] = value unless nested

        case value
        when Hash
          value.each do |k, v|
            attribute("#{name}#{k}", v, true)
          end
        else
          attr_accessor name.underscore
        end
      end

      # Set list of attributes that should never be included in update/create responses.
      def readonly_attributes(*attrs)
        self.attribute_definitions_readonly ||= ['CreatedDateUTC', 'UpdatedDateUTC']
        self.attribute_definitions_readonly += attrs.flatten
      end

      def from_xml(base_element, gateway = nil)
        args = gateway ? [{ gateway: gateway }] : []
        new(*args).from_xml(base_element)
      end

      def xml_element
        element_name || self.name.split('::').last
      end
    end

    def initialize(params = {})
      params.each do |k,v|
        self.send("#{k}=", v) if respond_to?("#{k}=")
      end
    end

    def ==(other)
      to_xml == other.to_xml
    end

    def to_xml(builder = Builder::XmlMarkup.new)
      builder.__send__(self.class.xml_element) do
        to_xml_attributes(builder)
      end
    end

    def from_xml(base_element)
      from_xml_attributes(base_element)
      self
    end

    def from_xml_attributes(element, attribute = nil, attr_definition = self.class.attribute_definitions)
      if Hash === attr_definition
        element.children.each do |child|
          next unless child.respond_to?(:name)

          child_attribute = child.name
          child_attr_definition = attr_definition[child_attribute]
          child_attr_name       = "#{attribute}#{child_attribute}" # SalesDetails/UnitPrice => SalesDetailsUnitPrice

          next unless child_attr_definition

          from_xml_attributes(child, child_attr_name, child_attr_definition)
        end

        return
      end

      if element.text.present? || element.children.present?
        value = case attr_definition
                when :boolean
                  element.text == "true"
                when :float
                  element.text.to_f
                when :integer
                  element.text.to_i
                when :currency
                  BigDecimal(element.text)
                when :date
                  Dates::Helpers.parse_date(element.text)
                when :datetime
                  Dates::Helpers.parse_date_time(element.text)
                when :datetime_utc
                  Dates::Helpers.parse_date_time_utc(element.text)
                when Array
                  array_from_xml(element, attr_definition)
                when Class
                  attr_definition.from_xml(element) if attr_definition.respond_to?(:from_xml)
                else
                  element.text
                end
      end

      send("#{attribute.underscore}=", value)
    end

    def array_from_xml(element, attr_definition)
      definition_klass = attr_definition.first
      element.children.map { |child_el| definition_klass.from_xml(child_el) }
    end

    def to_xml_attributes(builder = Builder::XmlMarkup.new, path = nil, attr_definitions = self.class.attribute_definitions)
      attr_definitions.each do |attr, value|
        next if self.class.attribute_definitions_readonly && self.class.attribute_definitions_readonly.include?(attr)

        case value
        when Hash
          builder.__send__(attr) do
            to_xml_attributes(builder, "#{path}#{attr}", value)
          end
        when Array
          raise UnsupportedAttributeType.new("#{value} instances don't respond to #to_xml") unless value.first.method_defined?(:to_xml)
          options = value.length > 1 ? value.last : {}

          value = send("#{path}#{attr}".underscore)
          value ||= [] unless options[:omit_if_empty]

          builder.__send__(attr) do |array_wrapper|
            value.map do |k|
              k.to_xml(array_wrapper)
            end
          end unless value.nil?
        else
          attr_value = send("#{path}#{attr}".underscore)
          builder.__send__(attr, attr_value) unless attr_value.nil?
        end
      end
    end

  end
end
