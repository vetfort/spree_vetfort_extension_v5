# require 'down'
require 'tempfile'
require "httparty"
require "securerandom"

class ImageProcessor
  API_ENDPOINT = "https://image-api.photoroom.com/v2/edit"
  DEFAULT_OUTPUT_SIZE = "2048x2048"

  class PhotoRoomClientError < StandardError; end

  attr_reader :api_key

  def initialize(api_key: ENV["PHOTOROOM_API_KEY"])
    @api_key = api_key
    raise ArgumentError, "api key is missing" if @api_key.to_s.strip.empty?
  end

  def call(image_url, output_size: DEFAULT_OUTPUT_SIZE, upscale: false, background_color: 'FFFFFF', timeout: 60)
    params = { outputSize: output_size, imageUrl: image_url }
    params[:"upscale.mode"] = "ai.fast" if upscale
    params[:"background.color"] = background_color if background_color

    response = HTTParty.get(
      API_ENDPOINT,
      headers: { "x-api-key" => api_key, "Accept" => "image/png" },
      query: params,
      timeout: timeout
    )

    raise_error!(response) unless response.success?

    io = Tempfile.new(["processed", ".png"], binmode: true)
    io.write(response.body)
    io.rewind
    io
  end

  private

  def raise_error!(response)
    snippet = response.body.is_a?(String) ? response.body.byteslice(0, 200) : ""
    raise PhotoRoomClientError, "PhotoRoom failed: #{response.code} #{response.message} #{snippet}"
  end
end
