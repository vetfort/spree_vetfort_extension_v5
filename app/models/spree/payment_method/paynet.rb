require "uri"
require "net/http"

module Spree
  class PaymentMethod::Paynet < Spree::PaymentMethod
    include Spree.railtie_routes_url_helpers

    preference :merchant_code, :string
    preference :secret_key, :string
    preference :sale_area_code, :string
    preference :notification_secret, :string
    preference :paynet_submit_form_url, :string # "https://test.paynet.md/acquiring/getecom"
    preference :paynet_api_url, :string # https://api-merchant.test.paynet.md/api/Payments/Send
    preference :paynet_auth_url, :string # https://api-merchant.test.paynet.md/auth
    preference :username, :string
    preference :password, :string
    preference :service_details_description, :string
    preference :ok_url, :string
    preference :cancel_url, :string

    preference :auto_capture, :boolean, default: true

    def available_for_store?(store)
      store.supported_currencies.include?('MDL')
    end

    def queue_webhooks_requests!; end

    def source_required?
      false
    end

    def purchase(amount, source, gateway_options, locale)
      order, payment = extract_order_and_payment(gateway_options)
      data = generate_data(order, payment, amount, gateway_options)
      signature, payment_id = send_payment_request(data.to_json)

      RedirectAttributes.new(
        operation: payment_id,
        paynet_submit_form_url: preferences[:paynet_submit_form_url],
        link_url_succes: preferences[:ok_url],
        link_url_cancel: preferences[:cancel_url],
        expiry_date: data['ExpiryDate'],
        signature: signature,
        lang: locale
      )
    end

    private

    def get_api_token
      Rails.cache.fetch('paynet_api_token', expires_in: 3.hours) do
        url = URI(preferences[:paynet_auth_url])

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = request_body

        response = https.request(request)
        token_data = JSON.parse(response.read_body)

        token_data["access_token"]
      end
    end

    def request_body
      {
        grant_type: 'password',
        username: preferences[:username],
        password: preferences[:password],
        merchantcode: preferences[:merchant_code],
        salearea: preferences[:sale_area_code]
      }.to_query
    end

    def generate_data(order, payment, amount, gateway_options)
      {
        invoice: payment.id,
        merchant_code: preferences[:merchant_code],
        link_url_success: preferences[:ok_url],
        link_url_cancel: preferences[:cancel_url],
        customer: customer(order, gateway_options),
        payer: nil,
        currency: iso_numeric_currency(order),
        external_date: Time.now.iso8601,
        expiry_date: (Time.now + 1.day).iso8601,
        services: [services(order)],
        money_type: nil
      }.deep_transform_keys { |key| key.to_s.camelize }
    end

    def services(order)
      {
        description: "VetFort",
        name: preferences[:service_details_description],
        amount: (order.total * 100).to_i,
        products: order.line_items.map.with_index do |item, index|
          {
            line_no: index + 1,
            code: sku(item),
            bar_code: sku(item),
            name: item.name,
            description: item.description,
            quantity: item.quantity,
            unit_price: (item.price * 100).to_i,
            total_amount: (item.price * item.quantity * 100).to_i,
          }
        end
      }
    end

    def sku(item)
      [item.variant.sku, item.variant.product.master.sku].find(&:present?)
    end

    def iso_numeric_currency(order)
      ::Money::Currency.find(order.currency).iso_numeric
    end

    def customer(order, gateway_options)
      address_hash = order.billing_address || order.shipping_address

      {
        code: gateway_options[:customer_id],
        name: gateway_options.dig(:shipping_address, :name) || 'Anonimous',
        name_first: address_hash.firstname,
        name_last: address_hash.lastname,
        country: nil,
        city: address_hash.city,
        address: format_address(address_hash),
        phone_number: address_hash.phone,
        email: gateway_options[:email]
      }
    end

    def format_address(address_hash)
      [
        address_hash[:name],
        address_hash[:address1],
        address_hash[:address2],
        address_hash[:city],
        address_hash[:state],
        address_hash[:zip],
        address_hash[:country]
      ].compact.join(", ")
    end

    def extract_order_and_payment(gateway_options)
      order_number, payment_number = gateway_options[:order_id].split('-')

      order = Spree::Order.find_by(number: order_number)
      payment = order.payments.find_by(number: payment_number)

      [order, payment]
    end

    def send_payment_request(data)
      token = get_api_token

      uri = URI(preferences[:paynet_api_url])
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "bearer #{token}"
      request['Content-Type'] = 'application/json'

      request.body = data
      response = https.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("Payment request failed: #{response.body}")
        Rails.cache.delete('paynet_api_token')

        raise "Payment request failed"
      end

      parsed_response = JSON.parse(response.read_body)

      [parsed_response['Signature'], parsed_response['PaymentId']]
    end

    class RedirectAttributes < Dry::Struct
      attribute :operation, Dry.Types::Coercible::Integer
      attribute :paynet_submit_form_url, Dry.Types::String
      attribute :link_url_succes, Dry.Types::String
      attribute :link_url_cancel, Dry.Types::String
      attribute :expiry_date, Dry.Types::String
      attribute :signature, Dry.Types::String | Dry.Types::Nil
      attribute :lang, Dry.Types::String
    end
  end
end
