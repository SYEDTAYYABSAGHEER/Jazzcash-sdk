# frozen_string_literal: true

module PaymentGateway
  class ResponseFormatter
    def self.format_charge_response(response)
      {
        success: response['pp_ResponseCode'] == '000',
        reference_id: response['pp_TxnRefNo'],
        message: response['pp_ResponseMessage'],
        raw_response: response
      }
    end

    def self.format_inquiry_response(response)
      {
        success: response['pp_ResponseCode'] == '000',
        reference_id: response['pp_TxnRefNo'],
        status: response['pp_TxnStatus'],
        message: response['pp_ResponseMessage'],
        raw_response: response
      }
    end

    def self.format_refund_response(response)
      {
        success: response['pp_ResponseCode'] == '000',
        reference_id: response['pp_TxnRefNo'],
        message: response['pp_ResponseMessage'],
        raw_response: response
      }
    end

    def self.format_error_response(error)
      {
        success: false,
        message: error.message,
        error_type: error.class.name
      }
    end
  end
end
