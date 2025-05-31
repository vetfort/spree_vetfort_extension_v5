module Structs
  class PaynetCallbackStruct < Dry::Struct
    transform_keys { |key| Types.to_snake_symbol(key) }

    PaymentSchema = Dry.Types::Hash.schema(
      id: Types::Strict::Integer,
      external_id: Types::Strict::Integer,
      sale_area_code?: Types::String.optional,
      customer: Types::Strict::String.optional,
      status_date: Types::Strict::String.optional,
      amount: Types::Strict::Integer.optional,
      merchant: Types::Strict::String.optional,
      card_mask?: Types::Strict::String.optional,
      card_expire_month?: Types::Strict::String.optional,
      card_expire_year?: Types::Strict::String.optional,
      card_issuer?: Types::Strict::String.optional,
      card_link_hash?: Types::Strict::String.optional
    ).with_key_transform { |key| Types.to_snake_symbol(key) }

    PaynetEventSchema = Dry.Types::Hash.schema(
      eventid: Types::Strict::Integer,
      event_type: Types::Strict::String,
      event_date: Types::Strict::String,
      payment: PaymentSchema
    ).with_key_transform { |key| Types.to_snake_symbol(key) }

    attribute :eventid, Types::Strict::Integer
    attribute :event_type, Types::Strict::String
    attribute :event_date, Types::Strict::String
    attribute :payment, PaymentSchema
    attribute :paynet, PaynetEventSchema

    def process!
      return unless paid?

      ActiveRecord::Base.transaction do
        payment_obj.complete!
        order.next unless order.completed?
      rescue => e
        Rails.logger.error "Failed to process payment: #{e.message}"
        raise ActiveRecord::Rollback
      end
    end

    def signature
      prepared_string = "#{formatted_date(event_date)}#{eventid}#{event_type}#{payment[:amount]}" \
                        "#{payment[:customer]}#{payment[:external_id]}" \
                        "#{payment[:id]}#{payment[:merchant]}#{formatted_date(payment[:status_date])}"

      generate_signature(prepared_string)
    end

    private

    def payment_obj
      Spree::Payment.find(payment[:external_id])
    end

    def payment_method_obj
      payment_obj.payment_method
    end

    def order
      payment_obj.order
    end

    def paid?
      event_type == 'PAID'
    end

    def formatted_date(date)
      DateTime.parse(date).strftime('%Y-%m-%dT%H:%M:%S')
    end

    def generate_signature(prepared_string)
      secret_key = payment_method_obj.preferences[:notification_secret]

      string_to_hash = prepared_string + secret_key
      md5_hash = Digest::MD5.digest(string_to_hash.encode('CP1251'))
      Base64.encode64(md5_hash).strip
    end
  end
end
