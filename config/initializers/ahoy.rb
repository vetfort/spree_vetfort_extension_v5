require 'ahoy_matey'

class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true

Ahoy.exclude_method = lambda do |controller, request|
  !request.path.start_with?("/admin") || request.path == "/up"
end
