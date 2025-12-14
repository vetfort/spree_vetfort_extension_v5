require "view_component"

class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
  include Turbo::StreamsHelper
  include Turbo::Streams::ActionHelper
  include Rails.application.routes.url_helpers
end
