module Attributable
  class Railtie < Rails::Railtie
    initializer "attributable.initialization" do
      class ActiveModel::EachValidator
        # add some additional methods to help json_schema generation
        def self.format
          nil
        end
        
      end
    end
  end
end


