Dir["#{File.dirname(__FILE__)}/normalizers/*.rb"].each {|f| require f}

AttributeNormalizer.configure do |config|
  Dir["#{File.dirname(__FILE__)}/normalizers/*.rb"].each do |n|
    name = n.split('/').last.sub('.rb','')
    normalizer = "Attributable::Normalizer::#{name.classify}".constantize
    config.normalizers[name.to_sym] = normalizer
  end
end
