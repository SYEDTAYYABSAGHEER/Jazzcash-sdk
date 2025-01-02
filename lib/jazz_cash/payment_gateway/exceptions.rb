# frozen_string_literal: true

module PaymentGateway
  module Exceptions
    class ServiceDown < StandardError; end
    class SystemError < StandardError; end
    class InvalidAmount < StandardError; end
    class InvalidPhoneNumber < StandardError; end
    class InvalidCNIC < StandardError; end
    class TransactionFailed < StandardError; end
    class InvalidCredentials < StandardError; end
    class InvalidMerchant < StandardError; end
  end
end
