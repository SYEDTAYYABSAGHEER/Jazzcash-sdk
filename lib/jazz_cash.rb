# frozen_string_literal: true

require_relative "jazz_cash/version"

module JazzCash
  class Client
    class Error < StandardError; end

    def initialize(user:, amount: nil)
      @user = user
      @amount = amount
    end

    def charge
      PaymentGateway::Client.instance.charge(
        user: @user,
        amount: @amount
      )
    end

    def inquire(reference_id:)
      PaymentGateway::Client.instance.inquire(
        reference_id: reference_id
      )
    end

    def refund(reference_id:, amount:)
      PaymentGateway::Client.instance.refund(
        reference_id: reference_id,
        amount: amount
      )
    end
  end
end
