require "view_component"

class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
  include Turbo::StreamsHelper
  include Turbo::Streams::ActionHelper
  include Rails.application.routes.url_helpers

  def markdown(text)
    @markdown_renderer ||= begin
      require 'redcarpet'
      renderer = Redcarpet::Render::HTML.new(
        hard_wrap: true,
        link_attributes: { target: '_blank' }
      )
      Redcarpet::Markdown.new(renderer, {
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        lax_spacing: true,
        space_after_headers: true,
        superscript: true
      })
    end

    @markdown_renderer.render(text).html_safe
  end
end
