defmodule PayNL.CaptureOptionsTest do
  use ExUnit.Case, async: false
  doctest PayNL

  @valid_params [
    amount_in_cents: 100,
    service_id: "123",
    api_token: "abc",
    token_id: "cba",
    bank_account_holder: "test muppet",
    bank_account_number: "NL0123TEST456789",
    notification_url: "https://example.com/ipn"
  ]

  test "creating with no options should return errors" do
    assert {:error, _} = PayNL.CaptureOptions.create()
  end

  test "creating with minimal required options shoud return a config" do
    assert {:ok, %PayNL.CaptureOptions{}} = PayNL.CaptureOptions.create(@valid_params)
  end

  test "should convert to post options" do
    {:ok, options} = PayNL.CaptureOptions.create(@valid_params)
    assert %{
             "amount" => 100,
             "serviceId" => "123",
             "token" => "abc",
             "bankAccountHolder" => "test muppet",
             "bankAccountNumber" => "NL0123TEST456789",
             "currency" => "EUR",
             "exchangeUrl" => "https://example.com/ipn"
           }
           == PayNL.CaptureOptions.to_post_map(options)
  end
end
