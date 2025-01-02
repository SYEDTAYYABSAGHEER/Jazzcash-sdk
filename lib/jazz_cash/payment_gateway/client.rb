# frozen_string_literal: true

require 'singleton'
require 'rest-client'
require 'digest/sha2'
require 'openssl'

module PaymentGateway
  class Client
    include Singleton

    SANDBOX_URL = ENV.fetch('JAZZCASH_URL', '')
    CHARGE_PATH = ENV.fetch('JAZZCASH_CHARGE_PATH', '')
    INQUIRY_PATH = ENV.fetch('JAZZCASH_INQUIRY_PATH', '')
    REFUND_PATH = ENV.fetch('JAZZCASH_REFUND_PATH', '')

    MERCHANT_ID = ENV.fetch('JAZZCASH_MERCHANT_ID', '')
    MERCHANT_PASSWORD = ENV.fetch('JAZZCASH_MERCHANT_PASSWORD', '')
    SHARED_SECRET = ENV.fetch('JAZZCASH_SHARED_SECRET', '')

    def charge(user:, amount:)
      @user = user
      @amount = amount.to_i
      @txn_ref_no = generate_txn_ref_no
      @txn_datetime = Time.current.strftime('%Y%m%d%H%M%S')
      @expiry_datetime = (Time.current + 2.days).strftime('%Y%m%d%H%M%S')

      user_payload = charge_attributes
      transaction_path = generate_url(CHARGE_PATH)
      
      log_debug("JazzCash Request URL: #{transaction_path}")
      log_debug("JazzCash Request Payload: #{user_payload.to_json}")
      log_debug("JazzCash Merchant ID: #{MERCHANT_ID}")
      log_debug("JazzCash Password: #{MERCHANT_PASSWORD}")
      log_debug("JazzCash User Phone: #{@user.phone_no}")
      log_debug("JazzCash User CNIC: #{@user.id_card}")
      
      response = make_post_request(path: transaction_path, payload: user_payload)
      log_debug("JazzCash Response: #{response.to_json}")
      
      ResponseFormatter.format_charge_response(response)
    rescue StandardError => e
      log_debug("JazzCash Error: #{e.message}")
      log_debug("JazzCash Error Backtrace: #{e.backtrace.join("\n")}")
      handle_error(e)
    end

    def inquire(reference_id:)
      @txn_ref_no = reference_id
      user_payload = inquiry_attributes
      transaction_path = generate_url(INQUIRY_PATH)
      
      log_debug("JazzCash Request URL: #{transaction_path}")
      log_debug("JazzCash Request Payload: #{user_payload.to_json}")
      log_debug("JazzCash Merchant ID: #{MERCHANT_ID}")
      log_debug("JazzCash Password: #{MERCHANT_PASSWORD}")
      log_debug("JazzCash Reference ID: #{@txn_ref_no}")
      
      response = make_post_request(path: transaction_path, payload: user_payload)
      log_debug("JazzCash Response: #{response.to_json}")
      
      ResponseFormatter.format_inquiry_response(response)
    rescue StandardError => e
      log_debug("JazzCash Error: #{e.message}")
      log_debug("JazzCash Error Backtrace: #{e.backtrace.join("\n")}")
      handle_error(e)
    end

    def refund(reference_id:, amount:)
      @txn_ref_no = reference_id
      @amount = amount
      @txn_datetime = Time.current.strftime('%Y%m%d%H%M%S')
      
      user_payload = refund_attributes
      transaction_path = generate_url(REFUND_PATH)
      
      log_debug("JazzCash Request URL: #{transaction_path}")
      log_debug("JazzCash Request Payload: #{user_payload.to_json}")
      log_debug("JazzCash Merchant ID: #{MERCHANT_ID}")
      log_debug("JazzCash Password: #{MERCHANT_PASSWORD}")
      log_debug("JazzCash Reference ID: #{@txn_ref_no}")
      log_debug("JazzCash Amount: #{@amount}")
      
      response = make_post_request(path: transaction_path, payload: user_payload)
      log_debug("JazzCash Response: #{response.to_json}")
      
      ResponseFormatter.format_refund_response(response)
    rescue StandardError => e
      log_debug("JazzCash Error: #{e.message}")
      log_debug("JazzCash Error Backtrace: #{e.backtrace.join("\n")}")
      handle_error(e)
    end

    private

    def generate_url(path)
      SANDBOX_URL + path
    end

    def make_post_request(path:, payload:)
      log_debug("JazzCash Initial Payload: #{payload.to_json}")
      
      hash = generate_secure_hash(payload.clone)
      payload[:pp_SecureHash] = hash
      
      log_debug("JazzCash Final Request Payload with Hash: #{payload.to_json}")
      log_debug("JazzCash Request URL: #{path}")
      
      response = RestClient.post(
        path,
        payload.to_json,
        { 'Content-Type': 'application/json' }
      )

      log_debug("JazzCash Response Status Code: #{response.code}")
      log_debug("JazzCash Response Headers: #{response.headers}")
      log_debug("JazzCash Response Body: #{response.body}")
      
      response = JSON.parse(response.body)
      raise "#{response['pp_ResponseMessage']}" if response["pp_ResponseCode"] != '000'
      response
    rescue RestClient::ExceptionWithResponse => e
      log_debug("JazzCash API Error Response: #{e.response.body}")
      log_debug("JazzCash API Error Status Code: #{e.response.code}")
      log_debug("JazzCash API Error Headers: #{e.response.headers}")
      handle_api_error(e)
    rescue StandardError => e
      raise Exceptions::ServiceDown, e.message
    end

    def handle_api_error(error)
      response = JSON.parse(error.response.body)
      log_debug("JazzCash API Error Details: #{response.to_json}")
      
      case response['pp_ResponseCode']
      when '124' then raise Exceptions::InvalidAmount, response['pp_ResponseMessage']
      when '125' then raise Exceptions::InvalidPhoneNumber, response['pp_ResponseMessage']
      when '126' then raise Exceptions::InvalidCNIC, response['pp_ResponseMessage']
      when '127' then raise Exceptions::InvalidCredentials, response['pp_ResponseMessage']
      when '128' then raise Exceptions::InvalidMerchant, response['pp_ResponseMessage']
      else
        raise Exceptions::TransactionFailed, response['pp_ResponseMessage']
      end
    end

    def handle_error(error)
      log_debug("JazzCash Error: #{error.message}")
      ResponseFormatter.format_error_response(error)
    end

    def generate_txn_ref_no
      "T#{Time.current.strftime('%Y%m%d%H%M%S')}"
    end

    def prepare_hash_message(payload)
      string_payload = payload.is_a?(Hash) ? payload.transform_keys(&:to_s) : payload
      
      filtered_payload = {
        'pp_Language' => string_payload['pp_Language'],
        'pp_MerchantID' => string_payload['pp_MerchantID'],
        'pp_Password' => string_payload['pp_Password'],
        'pp_TxnRefNo' => string_payload['pp_TxnRefNo'],
        'pp_MobileNumber' => string_payload['pp_MobileNumber'],
        'pp_CNIC' => string_payload['pp_CNIC'],
        'pp_Amount' => string_payload['pp_Amount'],
        'pp_TxnCurrency' => string_payload['pp_TxnCurrency'],
        'pp_TxnDateTime' => string_payload['pp_TxnDateTime'],
        'pp_BillReference' => string_payload['pp_BillReference'],
        'pp_Description' => string_payload['pp_Description'],
        'pp_TxnExpiryDateTime' => string_payload['pp_TxnExpiryDateTime']
      }

      filtered_payload.compact!
      
      log_debug("Fields for hash: #{filtered_payload}")
      filtered_payload
    end

    def generate_secure_hash(payload)
      filtered_payload = prepare_hash_message(payload)
      generator = HmacSha256Generator.new(SHARED_SECRET)
      hash = generator.generate_hash(filtered_payload)
      
      log_debug("JazzCash Generated Hash: #{hash}")
      hash
    end

    def charge_attributes
      {
        'pp_Language' => 'EN',
        'pp_MerchantID' => MERCHANT_ID,
        'pp_Password' => MERCHANT_PASSWORD,
        'pp_TxnRefNo' => @txn_ref_no,
        'pp_MobileNumber' => @user.phone_no,
        'pp_CNIC' => @user.id_card,
        'pp_Amount' => (@amount * 100).to_i.to_s,
        'pp_TxnCurrency' => 'PKR',
        'pp_TxnDateTime' => @txn_datetime,
        'pp_BillReference' => 'billref',
        'pp_Description' => 'Snooker Slam Payment',
        'pp_TxnExpiryDateTime' => @expiry_datetime,
        'pp_ReturnURL' => 'https://snookerslam.com/jazzcash/callback'
      }
    end

    def inquiry_attributes
      {
        'pp_MerchantID' => MERCHANT_ID,
        'pp_Password' => MERCHANT_PASSWORD,
        'pp_TxnRefNo' => @txn_ref_no,
        'pp_RetreivalReferenceNo' => @txn_ref_no
      }
    end

    def refund_attributes
      {
        'pp_MerchantID' => MERCHANT_ID,
        'pp_Password' => MERCHANT_PASSWORD,
        'pp_TxnRefNo' => @txn_ref_no,
        'pp_Amount' => (@amount * 100).to_i.to_s,
        'pp_TxnDateTime' => @txn_datetime,
        'pp_Description' => 'Refund for Snooker Slam Payment'
      }
    end

    def log_debug(message)
      Rails.logger.debug("[JazzCash Debug] #{message}")
    end
  end
end
