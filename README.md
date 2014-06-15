# Attributable

ActiveRecord model attributes standardised definition to enforce normalization and validation.

## Installation

Add this line to your application's Gemfile:

    gem 'attributable'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install attributable

## Usage

Defining attributes by type (default of the database type) means we can guarantee normalization and
validation.  Other validations and normalizations can be defined.

Simple example:

```ruby
class Thing < ActiveRecord::Base
  include Postgresql::MultiTableInheritable
  include Attributable

  attribute   :id,              :access => :readonly
  attribute   :name,            :type => :name
  attribute   :description,     :type => :printable  
  attributes  :created_at, :updated_at, :access => :readonly
  attributes  :created_by, :updated_by, :access => :readonly
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/attributable/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
