defmodule PayNL.TransactionOptionsTest do
  use ExUnit.Case, async: false
  doctest PayNL

  @valid_params [
    remote_ip: "127.0.0.1",
    amount_in_cents: 100,
    return_url: "https://example.com/return",
    notification_url: "https://example.com/ipn",
    service_id: "123",
    api_token: "abc"
  ]

  test "creating with no options should return errors" do
    assert {:error, _} = PayNL.TransactionOptions.create()
  end

  test "creating with minimal required options shoud return a config" do
    assert {:ok, %PayNL.TransactionOptions{}} = PayNL.TransactionOptions.create(@valid_params)
  end

  test "should convert to post options" do
    {:ok, options} = PayNL.TransactionOptions.create(@valid_params)
    assert  %{
              "amount" => 100,
              "finishUrl" => "https://example.com/return",
              "ipAddress" => "127.0.0.1",
              "serviceId" => "123",
              "testMode" => "0",
              "token" => "abc",
              "transaction[currency]" => "EUR",
              "enduser[language]" => "EN",
              "transaction[orderExchangeUrl]" => "https://example.com/ipn",
              "transaction[sendReminderEmail]" => "0"
            }
            == PayNL.TransactionOptions.to_post_map(options)
  end
end
