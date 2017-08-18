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
      assert %PayNL.PaymentOptions.Profile{
               active: false,
               costs_fixed: 0,
               costs_percentage: 0,
               countries: ["BE"],
               id: 436,
               image_url: "https://admin.pay.nl/images/payment_profiles/436.gif",
               name: "MisterCash / Bancontact",
               options: nil,
               payment_method_id: 4,
               visible_name: "MisterCash / Bancontact"
             } = List.last(payment_options)
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

  test "Requesting payment with valid credentials and a specific payment provider" do
    use_cassette "payment_url_with_valid_credentials_and_provider" do
      params = [{:payment_provider, :ideal} |@valid_params]
      {:ok, %PayNL.TransActionRequest{}} = PayNL.request_payment(params)
    end
  end

  test "should return a list for a specific country" do
    use_cassette "get_payment_options_for_country_success" do
      {:ok, payment_options_for_country} = PayNL.payment_options_for_country("BE")
      assert ["PayPal", "Telefonisch betalen", "MisterCash / Bancontact"] = payment_options_for_country
                                                                            |> Enum.map(&(&1.name))
                                                                            |> List.flatten
                                                                            |> Enum.uniq
    end
  end
end

