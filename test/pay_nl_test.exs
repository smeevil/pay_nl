defmodule PayNLTest do
  use ExUnit.Case
  use ExVCR.Mock

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
                 |> List.first()
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
          wire_transfer_id: "2000 0010 4364 7342",
          transaction_id: "1043647342X62be2",
          url: "https://api.pay.nl/controllers/payments/issuer.php?orderId=1043647342X62be2&entranceCode=4dccfb1da8876630de9f39af5e9ee4613f7acb8b&profileID=613&lang=NL"
        }
      } = PayNL.request_payment(@valid_params)
    end
  end

  test "Capturing payment" do
    use_cassette "capture_payment" do
      {:ok, %PayNL.CaptureRequest{mandate: "IO-9590-1286-3280"}} = PayNL.capture_payment(
        [
          amount_in_cents: 100,
          currency: "EUR",
          notification_url: "https://smee.io/paynl_ipn",
          bank_account_holder: "Test Muppet",
          bank_account_number: "NL24ABNA0601324080",
          description: "Test capture"
        ]
      )
    end
  end

  test "get_mandate_status_for" do
    use_cassette "mandate_info" do
      {:ok, :scheduled} = PayNL.get_mandate_status_for("IO-9590-1286-3280")
    end
  end


  test "cancel_capture" do
    use_cassette "cancel_mandate" do
      assert {:ok, :success} == PayNL.cancel_capture("IO-9590-1286-3280")
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
      assert ["iDEAL", "Incasso"] = payment_options_for_country
                         |> Enum.map(&(&1.name))
                         |> List.flatten
                         |> Enum.uniq
    end
  end

  test "getting payment status" do
    use_cassette "get_transaction_details" do
      assert {:ok, :pending} = PayNL.get_payment_status_for("665630593Xec1581")
    end
  end

  test "getting transaction details" do
    use_cassette "get_transaction_details" do
      assert{
              :ok,
              %{
                "connection" => %{
                  "blacklist" => "0",
                  "browserData" => "",
                  "city" => "",
                  "country" => "Unknown",
                  "countryName" => "Unknown",
                  "host" => "127.0.0.1",
                  "ipAddress" => "127.0.0.1",
                  "locationLat" => "",
                  "locationLon" => "",
                  "merchantCode" => "M-6066-3610",
                  "merchantName" => "TestCompany bv",
                  "orderIpAddress" => "127.0.0.1",
                  "orderReturnURL" => "https://example.com/return",
                  "trust" => "10"
                },
                "enduser" => %{
                  "accessCode" => "",
                  "address" => %{
                    "city" => "",
                    "countryCode" => "NL",
                    "regionCode" => "",
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
                    "regionCode" => "",
                    "streetName" => "",
                    "streetNumber" => "",
                    "streetNumberExtension" => "",
                    "zipCode" => ""
                  },
                  "language" => "NL",
                  "lastName" => "",
                  "phoneNumber" => "",
                  "sendConfirmMail" => ""
                },
                "paymentDetails" => %{
                  "paymentOptionId" => "613",
                  "cardType" => "",
                  "paymentMethodName" => "Transacties ",
                  "created" => "2019-02-11 14:38:13",
                  "amount" => %{
                    "currency" => "EUR",
                    "value" => "100"
                  },
                  "paymentMethodId" => "4",
                  "paymentMethodDescription" => "Pay Per Transaction",
                  "serviceName" => "example.com",
                  "identifierPublic" => "",
                  "cardExpire" => "",
                  "cardCountryCode" => "",
                  "modified" => "2019-02-11 14:38:13",
                  "amountPaidOriginal" => %{
                    "currency" => "EUR",
                    "value" => "0"
                  },
                  "secure" => "0",
                  "paymentProfileBrandName" => "",
                  "paidCosts" => "0",
                  "paidCostsVat" => "0",
                  "paidAttemps" => "1",
                  "paymentProfileName" => "SandBox",
                  "processTime" => "0",
                  "cardBrand" => "",
                  "paymentProfileCategoryName" => "",
                  "serviceId" => "TestService",
                  "orderNumber" => "424132",
                  "exchange" => "",
                  "state" => "20",
                  "stateDescription" => "Initialized",
                  "amountPaid" => %{
                    "currency" => "EUR",
                    "value" => "0"
                  },
                  "paymentOptionSubId" => "0",
                  "description" => "1043 6453 0200 0000",
                  "customerKey" => "",
                  "paidDuration" => "0",
                  "storno" => "0",
                  "paidBase" => "0",
                  "secureStatus" => "",
                  "amountOriginal" => %{
                    "currency" => "EUR",
                    "value" => "100"
                  },
                  "serviceDescription" => "testproduct",
                  "stateName" => "PENDING",
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
                  "domainId" => "",
                  "extra1" => "",
                  "extra2" => "",
                  "extra3" => "",
                  "info" => "",
                  "object" => "",
                  "paymentSessionId" => "1043645302",
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

