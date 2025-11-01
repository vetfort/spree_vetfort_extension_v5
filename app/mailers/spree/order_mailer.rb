module Spree
  class OrderMailer < VetfortMailer
    def confirm_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{current_store.name} #{Spree.t('order_mailer.confirm_email.subject')} ##{@order.number}"
      mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.url,
           reply_to: reply_to_address)
    end

    def store_owner_notification_email(order)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      subject = Spree.t('order_mailer.store_owner_notification_email.subject', store_name: current_store.name)

      if defined?(SendOrderToTelegramJob)
        SendOrderToTelegramJob.perform_later(order.id)
      end

      mail(to: 'vladimir@vetfort.md', from: from_address, subject: subject,
           store_url: current_store.url, reply_to: reply_to_address)
    end

    def cancel_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{current_store.name} #{Spree.t('order_mailer.cancel_email.subject')} ##{@order.number}"
      mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.url,
           reply_to: reply_to_address)
    end
  end
end
