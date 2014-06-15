# This method has disappeared from Rails 4.1
module ActiveRecord
  module AttributeMethods
    module ClassMethods
      def attribute_methods_generated?
        @attribute_methods_generated
      end
    end
  end
end

  


