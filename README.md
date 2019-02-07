PayNL
=====

PayNL is an Elixir library that wraps the pay.nl api for making payments and retrieve information about those.

## Getting started

```elixir
defp deps do
  [  {:paynl, "~> 0.1.0"},  ]
end
```

## Settings

PayNL requires the API credentials of your pay.nl account.
You can define either as ENV settings using the keys :
- `PAY_NL_SERVICE_ID`
- `PAY_NL_API_TOKEN`

or in your config.exs using :

```elixir
  config :paynl,
    service_id: "my-service-key",
    api_token: "my-api-token",
```

## Requesting a payment

```elixir
iex> PayNL.request_payment(
  remote_ip: "127.0.0.1",
  amount_in_cents: 100,
  currency: "EUR",
  return_url: "https://example.com/return",
  notification_url: "https://example.com/notify"
)

{:ok, %PayNL.TransActionRequest{
    wire_transfer_id: "0000 0008 6526 4048",
    transaction_id: "865264048X15d3f7",
    url: "https://api.pay.nl/controllers/payments/issuer.php?orderId=865264048X15d3f7&entranceCode=a58ef3885b2092420cabac3effde5e59f9561c2b&profileID=613"
  }
}
```

## License

The Cloudex Elixir library is released under the DWTFYW license. See the LICENSE file.
