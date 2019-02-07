defmodule PayNL.PaymentNotificationTest do

  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  @ipn %{
    "action" => "pending",
    "amount" => "1.000",
    "domain_id" => "",
    "enduser_id" => "0",
    "extra1" => "testing",
    "extra2" => "",
    "extra3" => "",
    "info" => "",
    "ip_address" => "127.0.0.1",
    "object" => "",
    "order_id" => "665630593Xec1581",
    "payment_method_id" => "4",
    "payment_profile_id" => "613",
    "payment_session_id" => "665630593",
    "pincode" => "174",
    "product_id" => "735613",
    "program_id" => "21772",
    "promotor_id" => "0",
    "secret" => "370680871082",
    "tool" => "",
    "website_id" => "1",
    "website_location_id" => "1"
  }

  test "it can verify a payment notification" do
    use_cassette "get_transaction_details" do
      assert {:ok, _details} = PayNL.PaymentNotification.verify(@ipn)
    end
  end

  test "it can refute a payment notification" do
    use_cassette "get_invalid_transaction_details" do
      assert {:error, "Transaction not found"} = PayNL.PaymentNotification.verify(Map.put(@ipn, "order_id", "gibberish"))
    end
  end
end
