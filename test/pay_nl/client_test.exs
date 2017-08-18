defmodule PayNL.ClientTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  doctest PayNL

  @invalid_params [
    remote_ip: "127.0.0.1",
    amount_in_cents: 100,
    return_url: "https://example.com/return",
    notification_url: "https://example.com/notify",
    service_id: "123",
    api_token: "abc",
    test: true
  ]

  @valid_params [
    remote_ip: "127.0.0.1",
    amount_in_cents: 100,
    return_url: "https://example.com/return",
    notification_url: "https://example.com/notify",
    test: true
  ]

  test "start transaction with invalid credentials" do
    {:ok, options} = PayNL.Options.create(@invalid_params)
    use_cassette "invalid_credentials" do
      assert {:error, :invalid_api_token_or_service_id} = PayNL.Client.start_transaction(options)
    end
  end

  test "start transaction with valid credentials" do
    {:ok, options} = PayNL.Options.create(@valid_params)
    use_cassette "valid_credentials" do
      assert {
               :ok,
               %{
                 "endUser" => %{
                   "blacklist" => "0"
                 },
                 "request" => %{
                   "errorId" => "",
                   "errorMessage" => "",
                   "result" => "1"
                 },
                 "transaction" => %{
                   "paymentReference" => "2000 0008 6526 4039",
                   "paymentURL" => "https://api.pay.nl/controllers/payments/issuer.php?orderId=865264039X7e6822&entranceCode=e31e5de02aa08ffa2ae0be760c5841dc8fa5b4ff&profileID=613",
                   "popupAllowed" => "0",
                   "transactionId" => "865264039X7e6822"
                 }
               }
             } = PayNL.Client.start_transaction(options)
    end
  end



  test "should return a list of payment options" do
    use_cassette "get_payment_options_success" do
      {:ok, credentials} = PayNL.Options.credentials(@valid_params)
      {:ok, payment_options} = PayNL.Client.get_payment_options(credentials)
      assert  %PayNL.PaymentOptions.Profile{
                active: false,
                costs_fixed: 0,
                costs_percentage: 0,
                countries: ["NL"],
                id: 10,
                image_url: "https://admin.pay.nl/images/payment_profiles/10.gif",
                name: "iDEAL",
                options: [
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "1",
                    image_url: "https://admin.pay.nl/images/payment_banks/1.png",
                    name: "ABN Amro",
                    visible_name: "ABN Amro"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "10",
                    image_url: "https://admin.pay.nl/images/payment_banks/10.png",
                    name: "Triodos Bank",
                    visible_name: "Triodos Bank"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "11",
                    image_url: "https://admin.pay.nl/images/payment_banks/11.png",
                    name: "Van Lanschot Bankiers",
                    visible_name: "Van Lanschot Bankiers"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "12",
                    image_url: "https://admin.pay.nl/images/payment_banks/12.png",
                    name: "Knab bank",
                    visible_name: "Knab bank"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "2",
                    image_url: "https://admin.pay.nl/images/payment_banks/2.png",
                    name: "Rabobank",
                    visible_name: "Rabobank"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "4",
                    image_url: "https://admin.pay.nl/images/payment_banks/4.png",
                    name: "ING Bank",
                    visible_name: "ING Bank"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "5",
                    image_url: "https://admin.pay.nl/images/payment_banks/5.png",
                    name: "SNS Bank",
                    visible_name: "SNS Bank"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "5080",
                    image_url: "https://admin.pay.nl/images/payment_banks/5080.png",
                    name: "Bunq",
                    visible_name: "Bunq"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "8",
                    image_url: "https://admin.pay.nl/images/payment_banks/8.png",
                    name: "ASN Bank",
                    visible_name: "ASN Bank"
                  },
                  %PayNL.PaymentOptions.Profile.Option{
                    active: true,
                    id: "9",
                    image_url: "https://admin.pay.nl/images/payment_banks/9.png",
                    name: "RegioBank",
                    visible_name: "RegioBank"
                  }
                ],
                payment_method_id: 4,
                visible_name: "iDEAL"
              } = List.first(payment_options)
    end
  end

  test "should return a list of banks" do
    use_cassette "get_banks_success" do
      {:ok, banks} = PayNL.Client.get_banks()
      assert %PayNL.Bank{
               available: true,
               id: 1,
               image: "https://www.pay.nl/betalen/images/tas2iDealBankAbnAmro.png",
               issuer_id: 31,
               name: "ABN Amro",
               swift: "ABNANL2A"
             } = List.first(banks)
    end
  end

  test "should return transaction details" do
    use_cassette "get_transaction_details" do
      {:ok, credentials} = PayNL.Options.credentials(@valid_params)
      {:ok, %{"paymentDetails" => _}} = PayNL.Client.get_transaction_details(credentials, "859462273Xbc39dc")
    end
  end
end