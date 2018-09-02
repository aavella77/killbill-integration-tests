$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'date'

require 'lib/logger_colored'
require 'test_base'

module KillBillIntegrationTests

  class TestCloud < Base

    TODAY = Date.today.to_s

    def setup
      setup_logger
      setup_base('test_cloud', DEFAULT_MULTI_TENANT_INFO, TODAY, ENV['KB_ADDRESS'] || DEFAULT_KB_ADDRESS, DEFAULT_KB_PORT)

      load_default_catalog
    end

    def teardown
      teardown_base
    end

    def test_classic
      threads = 2
      tasks = 20

      Thread.abort_on_exception = true
      pool = []
      1.upto(threads) do |t|
        pool << Thread.new do
          1.upto(tasks) do |j|
            scenario("#{t}-#{j}")
          end
        end
      end
      pool.each { |thr| thr.join }
    end

    private

    def scenario(id)
      KillBillClient.logger.info("===> Starting scenario #{id}")

      # Setup account
      external_key = SecureRandom.uuid.to_s
      account = create_account_with_data(@user, {:external_key => external_key, :currency => 'USD'}, @options)
      account = get_account(account.account_id, false, false, @options)
      assert_equal(account.external_key, external_key)

      # Setup payment method
      pm = KillBillClient::Model::PaymentMethod.new
      pm.account_id = account.account_id
      pm.external_key = SecureRandom.uuid.to_s
      pm.plugin_name = '__EXTERNAL_PAYMENT__'
      pm.create(true, @user, nil, nil, @options)

      # Create a subscription with a paying trial
      overrides = []
      override_trial = KillBillClient::Model::PhasePriceAttributes.new
      override_trial.phase_name = 'standard-monthly-trial'
      override_trial.fixed_price = rand(1..10000)
      overrides << override_trial
      bp = create_entitlement_base_with_overrides(account.account_id, 'Standard', 'MONTHLY', 'DEFAULT', overrides, @user, @options)
      check_entitlement(bp, 'Standard', 'BASE', 'MONTHLY', 'DEFAULT', TODAY, nil)

      # Verify invoice generated
      wait_for_expected_clause(1, account, @options, &@proc_account_invoices_nb)
      check_next_invoice_amount(1, override_trial.fixed_price, TODAY, account, @options, &@proc_account_invoices_nb)

      # Verify invoice balance
      wait_for_expected_clause(0, account, @options) do
        account.invoices(true, @options).last.balance
      end

      KillBillClient.logger.info("<=== Ending scenario #{id}")
    end
  end
end