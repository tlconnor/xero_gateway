require File.dirname(__FILE__) + '/../test_helper'

class GetInvoiceTest < Test::Unit::TestCase
  include TestHelper

  INVOICE_GET_URL = /Invoices(\/[0-9a-z\-]+)?$/i

  def setup
    @gateway = XeroGateway::Gateway.new(CONSUMER_KEY, CONSUMER_SECRET)

    if STUB_XERO_CALLS
      @gateway.xero_url = "DUMMY_URL"

      @gateway.stubs(:http_get).with do |client, url, params, headers|
        url =~ INVOICE_GET_URL && headers["Accept"] == "application/pdf"
      end.returns(get_file_as_string("get_invoice.pdf"))

      @gateway.stubs(:http_get).with {|client, url, params, headers| url =~ INVOICE_GET_URL && headers["Accept"].blank? }.returns(get_file_as_string("invoice.xml"))
      @gateway.stubs(:http_put).with {|client, url, body, params| url =~ /Invoices$/ }.returns(get_file_as_string("create_invoice.xml"))

    end
  end

  def test_get_invoice
    # Make sure there is an invoice in Xero to retrieve
    invoice = @gateway.create_invoice(dummy_invoice).invoice

    result = @gateway.get_invoice(invoice.invoice_id)
    assert result.success?
    assert !result.request_params.nil?
    assert !result.response_xml.nil?
    assert_equal result.invoice.invoice_number, invoice.invoice_number

    result = @gateway.get_invoice(invoice.invoice_number)
    assert result.success?
    assert !result.request_params.nil?
    assert !result.response_xml.nil?
    assert_equal result.invoice.invoice_id, invoice.invoice_id
  end

  def test_line_items_downloaded_set_correctly
    # Make sure there is an invoice in Xero to retrieve.
    example_invoice = @gateway.create_invoice(dummy_invoice).invoice

    # No line items.
    response = @gateway.get_invoice(example_invoice.invoice_id)
    assert_equal(true, response.success?)

    invoice = response.invoice
    assert_kind_of(XeroGateway::LineItem, invoice.line_items.first)
    assert_kind_of(XeroGateway::Invoice, invoice)
    assert_equal(true, invoice.line_items_downloaded?)
  end

  def test_get_invoice_pdf
    # Make sure there is an invoice in Xero to retrieve
    example_invoice = @gateway.create_invoice(dummy_invoice).invoice

    pdf_tempfile = @gateway.get_invoice(example_invoice.invoice_id, :pdf)
    assert_equal get_file_as_string("get_invoice.pdf"), File.open(pdf_tempfile.path).read
  end

end