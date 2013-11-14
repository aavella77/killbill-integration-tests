$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementAddOn < Base

    def setup
      @user = "EntitlementAddOn"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_simple

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(bps.size, 1)
      assert_equal(bps[0].subscription_id, bp.subscription_id)

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(aos.size, 1)
      assert_equal(aos[0].subscription_id, ao_entitlement.subscription_id)
    end

    def test_cancel_bp_imm

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options) # "2013-08-16"

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", nil)

      # Move clock before cancellation (BP still in trial)
      kb_clock_add_days(5, nil, @options) # "2013-08-21"

      # All default, system will cancel immediately since we are still in trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(bps.size, 1)
      check_subscription(bps[0], 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-21", DEFAULT_KB_INIT_DATE, "2013-08-21")
      check_events(bps[0].events, [{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                                   {:type => "START_BILLING", :date => "2013-08-01"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-08-21"},
                                   {:type => "STOP_BILLING", :date => "2013-08-21"}])

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(aos.size, 1)
      assert_equal(aos[0].subscription_id, ao_entitlement.subscription_id)
      check_subscription(aos[0], 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", "2013-08-21", "2013-08-16", "2013-08-21")
      check_events(aos[0].events, [{:type => "START_ENTITLEMENT", :date => "2013-08-16"},
                                   {:type => "START_BILLING", :date => "2013-08-16"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-08-21"},
                                   {:type => "STOP_BILLING", :date => "2013-08-21"}])
    end


    def test_cancel_bp_eot

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options)  # 16/08/2013

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", nil)

      # Move clock after trial before cancellation
      kb_clock_add_days(16, nil, @options) # 01/09/2013

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(bps.size, 1)

      check_subscription(bps[0], 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-01", DEFAULT_KB_INIT_DATE, "2013-09-30")
      check_events(bps[0].events, [{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                                   {:type => "START_BILLING", :date => "2013-08-01"},
                                   {:type => "PHASE", :date => "2013-08-31"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-09-01"},
                                   {:type => "STOP_BILLING", :date => "2013-09-30"}])

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)

      ## BUG : See https://github.com/killbill/killbill/issues/121 (wrong dates and dup events)
      check_subscription(aos[0], 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", "2013-09-01", "2013-08-16", "2013-09-30")
      check_events(aos[0].events, [{:type => "START_ENTITLEMENT", :date => "2013-08-16"},
                                   {:type => "START_BILLING", :date => "2013-08-16"},
                                   {:type => "PHASE", :date => "2013-09-01"},
                                   {:type => "STOP_ENTITLEMENT", :date => "2013-09-01"},
                                   {:type => "STOP_BILLING", :date => "2013-09-30"}])
    end


    #
    # TODO Try similar scenario (test_cancel_bp_eot) with entitlement cancellation EOT
    #


    def test_cancel_same_ao_differently

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after before cancellation (BP still in trial)
      kb_clock_add_days(3, nil, @options)  # 04/08/2013

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-04", "2013-08-01", "2013-08-04")

      # Create Add-on 2
      ao2 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao2, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-04", nil)


      requested_date = nil
      entitlement_policy = "END_OF_TERM"
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil

      ao2.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 3)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-01", "2013-08-04", "2013-08-01", "2013-08-04")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      check_subscription(ao2, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-04", "2013-08-31", "2013-08-04", "2013-08-31")

    end


    #
    # TODO : cancel / uncancel single AO
    #

    #
    # TODO : cancel / uncancel BP with AO
    #



    def test_complex_ao

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock and create Add-on 1  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      # Second invoice  05/08/2013 ->  31/08/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)


      # Move clock and create Add-on 2 (BP still in trial)
      kb_clock_add_days(10, nil, @options) # 15/08/2013

      # Third invoice  15/08/2013 ->  31/08/2013
      ao2 = create_entitlement_ao(bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options) # (Subscription Aligned)
      check_entitlement(ao2, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-15", nil)

      # Fourth invoice
      # BP : 31/08/2013 ->  30/09/2013
      # AO1 : 31/08/2013 ->  01/09/2013  (end of discount)
      # AO2 : 31/08/2013 ->  15/09/2013   (end of discount)
      kb_clock_add_days(16, nil, @options) # 31/08/2013


      # Fifth invoice AO1 01/09/2013 -> 30/09/2013 (Recurring Phase)
      kb_clock_add_days(1, nil, @options) # 01/09/2013

      # Change Plan for BP (future cancel date = 30/09/2013)  => AO1 is now included in new plan
      requested_date = nil
      billing_policy = "END_OF_TERM"
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)

      # Retrieves subscription and check cancellation date for AO1 is 30/09/2013
      subscriptions = get_subscriptions(bp.bundle_id, @options)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil, DEFAULT_KB_INIT_DATE, nil)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", "2013-09-30", "2013-08-05", "2013-09-30")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      check_subscription(ao2, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-15", nil, "2013-08-15", nil)

      # Seventh invoice AO2 15/09/2013 -> 30/09/2013 (Recurring Phase, aligns to BCD)
      kb_clock_add_days(14, nil, @options) # 15/09/2013

      # Eight invoice AO2
      # BP : 30/09/2013 ->  31/10/2013
      # AO1 : (CANCELLED)
      # AO2 : 30/09/2013 ->  31/10/2013
      kb_clock_add_days(15, nil, @options) # 30/09/2013


      # Future cancel BP  (and therefore ADD_ON)

      requested_date = nil
      entitlement_policy = "END_OF_TERM"  # STEPH Note it would be interesting to check with IMM to see if we can un-cancel later
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(subscriptions.size, 3)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-10-31", DEFAULT_KB_INIT_DATE, "2013-10-31")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      check_subscription(ao2, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-15", "2013-10-31", "2013-08-15", "2013-10-31")

      # uncancel

    end


  end
end

