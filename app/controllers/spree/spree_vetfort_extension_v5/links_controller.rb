class Spree::SpreeVetfortExtensionV5::LinksController < ApplicationController
  layout 'spree_vetfort_extension_v5/application'

  def index
    @links_component = SpreeVetfort::LinksComponent.new
  end
end
