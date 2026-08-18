require File.expand_path('../../../../../test/test_helper', __FILE__)

class PurchaseRequestTest < ActiveSupport::TestCase
  def setup
    @original_settings = Setting.plugin_redmine_purchase_requests
  end

  def teardown
    Setting.plugin_redmine_purchase_requests = @original_settings
  end

  # Only the :estimated_price errors are inspected, so the record does not
  # need to be otherwise valid or persisted. Other validations report against
  # :description, :status and friends, which keeps them out of the way.
  def price_errors(estimated_price)
    request = PurchaseRequest.new(
      title: 'Test purchase request',
      priority: 'normal',
      estimated_price: estimated_price
    )
    request.valid?
    request.errors[:estimated_price]
  end

  def with_max_amount(value)
    Setting.plugin_redmine_purchase_requests = { 'max_purchase_amount' => value }
  end

  test 'rejects an estimated price above the configured maximum' do
    with_max_amount('1000.00')
    assert_not_empty price_errors('1000.01'),
                     'expected a price over the cap to be rejected'
  end

  test 'accepts an estimated price exactly at the configured maximum' do
    with_max_amount('1000.00')
    assert_empty price_errors('1000.00'),
                 'the cap itself must remain allowed'
  end

  test 'accepts an estimated price below the configured maximum' do
    with_max_amount('1000.00')
    assert_empty price_errors('999.99')
  end

  test 'ignores a blank estimated price' do
    with_max_amount('1000.00')
    assert_empty price_errors(nil)
  end

  test 'falls back to the column ceiling when the maximum is unset' do
    with_max_amount('')
    assert_empty price_errors('9999999999999.99'),
                 'the fallback must allow the full precision-15 column range'
    assert_not_empty price_errors('10000000000000.00'),
                     'values past the column ceiling must still be rejected'
  end

  test 'falls back to the column ceiling when the maximum is zero' do
    with_max_amount('0')
    assert_empty price_errors('9999999999999.99')
  end

  # Guards the reason the cap exists: IDR amounts overflow the old
  # precision-10 column, which topped out at 99,999,999.99.
  test 'allows large denomination currency amounts past the old precision limit' do
    with_max_amount('9999999999999.99')
    assert_empty price_errors('150000000.00')
  end
end
