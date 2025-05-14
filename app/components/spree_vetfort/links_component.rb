# frozen_string_literal: true

class SpreeVetfort::LinksComponent < ViewComponent::Base
  def vetfort_link
    ENV.fetch('VETFORT_LINK', 'https://vetfort.md')
  end

  def instagram_link
    ENV.fetch('INSTAGRAM_LINK', 'https://www.instagram.com/vetfort.md/')
  end

  def tiktok_link
    ENV.fetch('TIKTOK_LINK', 'https://www.tiktok.com/@vetfort_zoomagazin?_t=8mwF8K1PDZG')
  end

  def logo_image_url
    SpreeVetfortExtensionV5::Images.logo
  end

  def instagram_image_url
    SpreeVetfortExtensionV5::Images.instagram
  end

  def tiktok_image_url
    SpreeVetfortExtensionV5::Images.tiktok
  end
end
