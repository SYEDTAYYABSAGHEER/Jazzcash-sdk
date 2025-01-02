# frozen_string_literal: true

require 'singleton'

module PaymentGateway
  class PayloadFormatter
    include Singleton

    def charge_transaction
      {
        pp_Language: 'EN',
        pp_TxnCurrency: 'PKR',
        pp_SubMerchantID: '',
        pp_DiscountedAmount: '',
        ppmpf_1: '',
        ppmpf_2: '',
        ppmpf_3: '',
        ppmpf_4: '',
        ppmpf_5: ''
      }
    end

    def inquire_transaction
      {
        pp_Language: 'EN',
        pp_TxnCurrency: 'PKR',
        pp_TxnType: 'MWALLET'
      }
    end

    def refund_transaction
      {
        pp_Language: 'EN',
        pp_TxnCurrency: 'PKR',
        pp_TxnType: 'MWALLET',
        pp_TxnRefundType: 'FULL'
      }
    end
  end
end
