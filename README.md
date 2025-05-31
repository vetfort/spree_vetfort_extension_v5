this extension includes patches for

## app/views/spree/admin/dashboard/_visits.html.erb
fixed `<%= flag_emoji(Country.find_by_name(location.first)&.first) %>`

method find_by_name [was removed](https://github.com/countries/countries/blob/6a786cfa2b75eae14d774d1eeba4d31021dc8e3a/README.md#attribute-based-finder-methods)

## added links page
`app/controllers/spree/spree_vetfort_extension_v5/links_controller.rb`

## also includes
- tailwind
- mjml
- ahoy_matey
- geocoder
- dry gems
- view_component
