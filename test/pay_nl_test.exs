defmodule PayNLTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir("test/vcr_cassettes")
    :ok
  end

  doctest PayNL

  @valid_params [
    remote_ip: "127.0.0.1",
    amount_in_cents: 100,
    return_url: "https://example.com/return",
    notification_url: "https://example.com/notify",
    test: true
  ]

  @invalid_params [
    remote_ip: "127.0.0.1",
    amount_in_cents: 100,
    return_url: "https://example.com/return",
    notification_url: "https://example.com/notify",
    service_id: "123",
    api_token: "abc",
    test: true
  ]

  test "should return a list of payment options" do
    use_cassette "get_payment_options_success" do
      {:ok, payment_options} = PayNL.payment_options

      assert %PayNL.PaymentOptions.Profile.Option{
               active: true,
               id: "1",
               image_url: "https://admin.pay.nl/images/payment_banks/1.png",
               name: "ABN Amro",
               visible_name: "ABN Amro"
             } = payment_options
                 |> List.last()
                 |> Map.get(:options)
                 |> List.first
    end
  end

  test "Requesting payment with invalid credentials" do
    use_cassette "payment_url_with_invalid_credentials" do
      {:error, :invalid_api_token_or_service_id} = PayNL.request_payment(@invalid_params)
    end
  end

  test "Requesting payment with valid credentials" do
    use_cassette "payment_url_with_valid_credentials" do
      {
        :ok,
        %PayNL.TransActionRequest{
          wire_transfer_id: "0000 0008 6526 4048",
          transaction_id: "865264048X15d3f7",
          url: "https://api.pay.nl/controllers/payments/issuer.php?orderId=865264048X15d3f7&entranceCode=a58ef3885b2092420cabac3effde5e59f9561c2b&profileID=613"
        }
      } = PayNL.request_payment(@valid_params)
    end
  end

  test "Capturing payment" do
    use_cassette "capture_payment" do
      {:ok, %PayNL.CaptureRequest{mandate: "IO-1213-0213-5680"}} = PayNL.capture_payment(
        [
          amount_in_cents: 100,
          currency: "EUR",
          notification_url: "https://smee.io/paynl_ipn",
          bank_account_holder: "Test Muppet",
          bank_account_number: "NL24ABNA01234567",
          description: "Test capture"
        ]
      )
    end
  end

  test "get_mandate_status_for" do
    use_cassette "mandate_info" do
      {
        :ok,
        %{
          "request" => %{
            "errorId" => "",
            "errorMessage" => "",
            "result" => "1"
          },
          "result" => %{
            "directDebit" => "",
            "mandate" => %{
              "amount" => "100",
              "bankaccounOwner" => "Test Muppet",
              "bankaccountBic" => "ABNANL2A",
              "bankaccountNumber" => "NL24ABNA012345678",
              "description" => "Test capture",
              "email" => "",
              "extra1" => "",
              "extra2" => "",
              "info" => "",
              "intervalPeriod" => "0",
              "intervalQuantity" => "1",
              "intervalValue" => "0",
              "ipAddress" => "185.47.134.204",
              "mandateId" => "IO-1213-0213-5680",
              "object" => "",
              "state" => "single",
              "type" => "single"
            }
          }
        }
      } = PayNL.get_mandate_status_for("IO-1213-0213-5680")
    end
  end


  test "cancel_capture" do
    use_cassette "cancel_mandate" do
      assert {:ok, :success} == PayNL.cancel_capture("IO-1213-0213-5680")
    end
  end

  test "Requesting payment with valid credentials and a specific payment provider" do
    use_cassette "payment_url_with_valid_credentials_and_provider" do
      params = [{:payment_provider, :ideal} | @valid_params]
      {:ok, %PayNL.TransActionRequest{}} = PayNL.request_payment(params)
    end
  end

  test "should return a list for a specific country" do
    use_cassette "get_payment_options_for_country_success" do
      {:ok, payment_options_for_country} = PayNL.payment_options_for_country("NL")
      assert ["iDEAL"] = payment_options_for_country
                         |> Enum.map(&(&1.name))
                         |> List.flatten
                         |> Enum.uniq
    end
  end

  test "getting payment status" do
    use_cassette "get_transaction_details" do
      assert {:ok, :expired} = PayNL.get_payment_status_for("665630593Xec1581")
    end
  end

  test "getting transaction details" do
    use_cassette "get_transaction_details" do
      assert {
               :ok,
               %{
                 "connection" => %{
                   "blacklist" => "0",
                   "browserData" => "",
                   "city" => "",
                   "country" => "Unknown",
                   "countryName" => "Unknown",
                   "host" => "localhost",
                   "ipAddress" => "127.0.0.1",
                   "locationLat" => "",
                   "locationLon" => "",
                   "merchantCode" => "M-1234-4321",
                   "merchantName" => "TestBV",
                   "orderIpAddress" => "127.0.0.1",
                   "orderReturnURL" => "http://www.example.com/finished",
                   "trust" => "10"
                 },
                 "enduser" => %{
                   "accessCode" => "",
                   "address" => %{
                     "city" => "",
                     "countryCode" => "NL",
                     "streetName" => "",
                     "streetNumber" => "",
                     "streetNumberExtension" => "",
                     "zipCode" => ""
                   },
                   "bankAccount" => "",
                   "bic" => "",
                   "company" => %{
                     "cocNumber" => "",
                     "countryCode" => "NL",
                     "name" => "",
                     "vatNumber" => ""
                   },
                   "confirmMailTemplate" => "",
                   "customerReference" => "",
                   "customerTrust" => "",
                   "dob" => "",
                   "emailAddress" => "",
                   "gender" => "",
                   "iban" => "",
                   "initials" => "",
                   "invoiceAddress" => %{
                     "city" => "",
                     "countryCode" => "NL",
                     "gender" => "",
                     "initials" => "",
                     "lastName" => "",
                     "streetName" => "",
                     "streetNumber" => "",
                     "streetNumberExtension" => "",
                     "zipCode" => ""
                   },
                   "language" => "en",
                   "lastName" => "",
                   "phoneNumber" => "",
                   "sendConfirmMail" => ""
                 },
                 "paymentDetails" => %{
                   "paymentOptionId" => "10",
                   "cardType" => "",
                   "currenyAmount" => "1000",
                   "paymentMethodName" => "Transacties ",
                   "created" => "2017-07-25 09:38:33",
                   "amount" => "1000",
                   "paymentMethodId" => "4",
                   "paymentMethodDescription" => "Pay Per Transaction",
                   "serviceName" => "example.com",
                   "identifierPublic" => "",
                   "cardExpire" => "",
                   "cardCountryCode" => "",
                   "paidCurrenyAmount" => "0",
                   "modified" => "2017-07-25 13:47:30",
                   "secure" => "0",
                   "paidCosts" => "0",
                   "paidCostsVat" => "0",
                   "paidAttemps" => "1",
                   "paymentProfileName" => "iDEAL",
                   "processTime" => "14937",
                   "cardBrand" => "",
                   "serviceId" => "TestService",
                   "exchange" => "",
                   "state" => "-80",
                   "stateDescription" => "Expired",
                   "paidCurrency" => "EUR",
                   "paymentOptionSubId" => "0",
                   "description" => "Pay.nl 8594 6227 3073 5613",
                   "customerKey" => "",
                   "paidDuration" => "0",
                   "storno" => "0",
                   "paidBase" => "0",
                   "secureStatus" => "",
                   "serviceDescription" => "Example",
                   "stateName" => "CANCEL",
                   "paidAmount" => "0",
                   "identifierName" => "",
                   "identifierHash" => ""
                 },
                 "request" => %{
                   "errorId" => "",
                   "errorMessage" => "",
                   "result" => "1"
                 },
                 "saleData" => %{
                   "deliveryDate" => "",
                   "invoiceDate" => "",
                   "orderData" => ""
                 },
                 "statsDetails" => %{
                   "extra1" => "",
                   "extra2" => "",
                   "extra3" => "",
                   "info" => "",
                   "object" => "",
                   "paymentSessionId" => "859462273",
                   "promotorId" => "0",
                   "tool" => "",
                   "transferData" => ""
                 },
                 "stornoDetails" => %{
                   "bankAccount" => "",
                   "bic" => "",
                   "city" => "",
                   "datetime" => "",
                   "emailAddress" => "",
                   "iban" => "",
                   "reason" => "",
                   "stornoAmount" => "",
                   "stornoId" => ""
                 }
               }
             } = PayNL.get_transaction_details_for("665630593Xec1581")
    end
  end
end

