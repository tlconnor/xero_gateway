module XeroGateway
  class Payment
    include Money
    include Dates

    # Any errors that occurred when the #valid? method called.
    attr_reader :errors

    # All accessible fields
    attr_accessor :invoice_id, :invoice_number, :account_id, :code, :payment_id,
                  :payment_type, :date, :amount, :reference, :currency_rate,
                  :currency_code, :updated_at, :reconciled,
                  :credit_note_id, :credit_note_number
    alias_method :reconciled?, :reconciled

    # Xero::Gateway associated with this invoice.
    attr_accessor :gateway

    def initialize(params = {})
      @errors ||= []

      params.each do |k,v|
        self.send("#{k}=", v)
      end
    end

    def self.from_xml(payment_element)
      payment = Payment.new
      payment_element.children.each do | element |
        case element.name
          when 'PaymentID'      then payment.payment_id = element.text
          when 'PaymentType'    then payment.payment_type = element.text
          when 'Date'           then payment.date = parse_date_time(element.text)
          when 'UpdatedDateUTC' then payment.updated_at = parse_date_time(element.text)
          when 'Amount'         then payment.amount = BigDecimal(element.text)
          when 'Reference'      then payment.reference = element.text
          when 'CurrencyRate'   then payment.currency_rate = BigDecimal(element.text)
          when 'Invoice'
            payment.invoice_id = element.elements["//InvoiceID"].text
            payment.invoice_number = element.elements["//InvoiceNumber"].text
          when 'CreditNote'
            payment.credit_note_id = element.elements["//CreditNoteID"].text
            payment.credit_note_number = element.elements["//CreditNoteNumber"].text
          when 'IsReconciled'   then payment.reconciled = (element.text == "true")
          when 'Account'        then payment.account_id = element.elements["//AccountID"].text
        end
      end
      payment
    end

    def ==(other)
      [:payment_id, :date, :amount].each do |field|
        return false if send(field) != other.send(field)
      end
      return true
    end

    def to_xml(b = Builder::XmlMarkup.new)
      b.Payment do

        b.PaymentID          self.payment_id        if self.payment_id
        b.PaymentType        self.payment_type      if self.payment_type

        if self.invoice_id || self.invoice_number
          b.Invoice do |i|
            i.InvoiceID         self.invoice_id     if self.invoice_id
            i.InvoiceNumber     self.invoice_number if self.invoice_number
          end
        end

        if self.credit_note_id || self.credit_note_number
          b.CreditNote do |i|
            i.CreditNoteID         self.credit_note_id     if self.credit_note_id
            i.CreditNoteNumber     self.credit_note_number if self.credit_note_number
          end
        end

        if self.account_id || self.code
          b.Account do |a|
            a.AccountID         self.account_id     if self.account_id
            a.Code              self.code           if self.code
          end
        end

        b.Amount            self.amount         if self.amount
        b.CurrencyRate      self.currency_rate  if self.currency_rate
        b.Reference         self.reference      if self.reference

        if self.reconciled?
          b.IsReconciled true
        end

        b.Date              self.class.format_date(self.date || Date.today)
      end
    end

    # Creates this payment record with the associated gateway.
    # If no gateway set, raise a NoGatewayError exception.
    def create
      raise NoGatewayError unless gateway
      gateway.create_payment(self)
    end
  end
end
