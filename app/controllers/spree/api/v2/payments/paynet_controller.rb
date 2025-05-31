class Spree::Api::V2::Payments::PaynetController < ::Spree::Api::V2::ResourceController
  def callback
    payment_callback = Structs::PaynetCallbackStruct.new(callback_params)

    if payment_callback.signature != request.headers['Hash']
      render json: { status: 'error', message: 'Invalid signature' }, status: :unprocessable_entity
      return
    end

    if payment_callback.process!
      render json: { status: 'ok' }
    else
      render json: { status: 'error' }, status: :unprocessable_entity
    end
  end

  private

  def callback_params
    params.permit!
  end
end
