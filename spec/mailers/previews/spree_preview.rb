class SpreePreview < ActionMailer::Preview
  def order_confirmation
    order = Spree::Order.find(1090)
    Spree::OrderMailer.confirm_email(order)
  end

  def store_owner_notification
    order = Spree::Order.find(1090)
    Spree::OrderMailer.store_owner_notification_email(order)
  end

  def order_canceled
    order = Spree::Order.complete.last || Spree::Order.last
    Spree::OrderMailer.cancel_email(order)
  end

  def reset_password_instructions
    user = Spree::User.first || Spree::User.create!(
      email: 'test@example.com',
      password: 'password',
      password_confirmation: 'password'
    )
    Spree::UserMailer.reset_password_instructions(user, 'token123')
  end
end
