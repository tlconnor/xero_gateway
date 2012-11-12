module XeroGateway
  class Payment
    include Money
    include Dates

    # Any errors that occurred when the #valid? method called.
    attr_reader :errors

    # All accessible fields
    attr_accessor :invoice_id, :invoice_number, :account_id, :code, :payment_id, :date, :amount, :reference, :currency_rate

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
          when 'PaymentID'    then payment.payment_id = element.text
          when 'Date'         then payment.date = parse_date_time(element.text)
          when 'Amount'       then payment.amount = BigDecimal.new(element.text)
          when 'Reference'    then payment.reference = element.text
          when 'CurrencyRate' then payment.currency_rate = BigDecimal.new(element.text)
          when 'Invoice'      then payment.send("#{element.children.first.name.underscore}=", element.children.first.text)
          when 'Account'      then payment.send("#{element.children.first.name.underscore}=", element.children.first.text)
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

        if self.invoice_id || self.invoice_number
          b.Invoice do |i|
            i.InvoiceID         self.invoice_id     if self.invoice_id
            i.InvoiceNumber     self.invoice_number if self.invoice_number
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

        b.Date              self.class.format_date(self.date || Date.today)
      end
    end


  end
end