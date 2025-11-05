# app/services/bots/telegram_order_formatter.rb
module Bots
  class TelegramOrderFormatter
    MAX_LINE_NAME = 40
    HOST     = ENV.fetch("ADMIN_HOST", "https://vetfort.md")

    def self.html(order)
      [
        "🛒 <b>Order <a href=\"#{order_admin_url(order)}\">#{ERB::Util.html_escape(order.number)}</a></b>",
        "Date: #{I18n.l(order.created_at, format: :long)}",
        "Total: <b>#{ERB::Util.html_escape(order.display_total.to_s)}</b>",
        "",
        "<b>Payments</b>",
        payments_block(order),
        "",
        "<b>Customer</b>",
        customer_block(order)
      ].join("\n")
    end

    # ----- Payments (статус + метод) -----
    def self.payments_block(order)
      payments = order.payments.order(created_at: :asc)
      return "—" if payments.blank?

      payments.map do |payment|
        state_label = Spree.t("payment_states.#{payment.state}")
        method_name = payment.payment_method&.name.to_s
        "• #{ERB::Util.html_escape(method_name)} - #{state_label}"
      end.join("\n")
    end

    # ----- Customer -----
    def self.customer_block(order)
      a = order.bill_address || order.ship_address
      lines = []
      lines << "Name: #{ERB::Util.html_escape(a&.full_name.to_s)}"
      lines << "Email: #{ERB::Util.html_escape(order.email.to_s)}"

      phone = a&.phone.presence || order.ship_address&.phone
      lines << "Phone: #{ERB::Util.html_escape(phone.to_s)}" if phone.present?

      address_str = [
        a&.address1, a&.address2,
        [a&.city, a&.state_text].compact.join(", "),
        a&.zipcode, a&.country&.name
      ].compact.reject(&:blank?).join(", ")

      if address_str.present?
        maps_url = "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(address_str)}"
        lines << %Q(Address: <a href="#{maps_url}">#{ERB::Util.html_escape(address_str)}</a>)
      end

      lines.join("\n")
    end

    # ----- URLs -----
    def self.order_admin_url(order)
      Spree::Core::Engine.routes.url_helpers.edit_admin_order_url(
        order, host: HOST
      )
    end
  end
end
