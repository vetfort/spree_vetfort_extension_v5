class PaynetService
  def call(order, locale)
    payment = order.unprocessed_payments.first
    payment.started_processing!

    payment.payment_method.purchase(payment.amount, payment.source, payment.gateway_options, locale)
  end
end
