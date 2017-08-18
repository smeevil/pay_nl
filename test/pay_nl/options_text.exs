defmodule PayNL.OptionsTest do
  use ExUnit.Case, async: false
  doctest PayNL

  @valid_params [
    remote_ip: "127.0.0.1",
    amount_in_cents: 100,
    return_url: "https://example.com/return",
    service_id: "123",
    api_token: "abc"
  ]

  test "creating with no options should return errors" do
    assert {:error, _} = PayNL.Options.create()
  end

  test "creating with minimal required options shoud return a config" do
    assert {:ok, %PayNL.Options{}} = PayNL.Options.create(@valid_params)
  end

  test "should convert to post options" do
    {:ok, options} = PayNL.Options.create(@valid_params)
    assert %{
             "amount" => 100,
             "finishUrl" => "https://example.com/return",
             "ipAddress" => "127.0.0.1",
             "serviceId" => "123",
             "token" => "abc",
             "testMode" => "0",
             "transaction[currency]" => "EUR"
           } == PayNL.Options.to_post_map(options)
  end
end
