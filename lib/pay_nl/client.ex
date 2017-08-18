defmodule PayNL.Client do
  @moduledoc """
  This module wraps the json api of Pay.NL using Maxwell
  """

  use Maxwell.Builder, [:get, :post]

  middleware Maxwell.Middleware.BaseUrl, "https://rest-api.pay.nl/"
  middleware Maxwell.Middleware.Headers, %{"content-type" => "application/x-www-form-urlencoded"}
  middleware Maxwell.Middleware.Opts, connect_timeout: 3000
  middleware Maxwell.Middleware.Json
  #  middleware Maxwell.Middleware.Logger

  adapter Maxwell.Adapter.Hackney

  @doc """
  Will request all available payment options at pay.nl that are accociated with the account
  """
  @spec get_payment_options({:ok, options :: %PayNL.Options{}} | {:error, any}) :: {:ok, map} | {:error, any()}
  def get_payment_options({:ok, %PayNL.Options{} = options}), do: get_payment_options(options)
  def get_payment_options({:error, _} = error), do: error
  def get_payment_options(%PayNL.Options{} = options) do
    "/v7/Transaction/getServicePaymentOptions/json?serviceID=#{options.service_id}&token=#{options.api_token}"
    |> new
    |> get
    |> process_response
    |> PayNL.PaymentOptions.process_results
  end

  @doc """
  Will request all supported iDeal banks and their current availability
  """
  @spec get_banks :: {:ok, list(%PayNL.Bank{})} | {:error, binary}
  def get_banks do
    "/v7/Transaction/getBanks/json"
    |> new
    |> get
    |> process_response
    |> PayNL.Bank.json_to_struct
  end

  @doc"""
  This call will prepare a payment at pay.nl and returns a redirect url to send the client to confirm payment.
  """
  @spec start_transaction(options :: %PayNL.Options{}) :: {:ok, %PayNL.TransActionRequest{}}
  def start_transaction(%PayNL.Options{} = options) do
    "/v7/Transaction/start/json"
    |> new
    |> put_req_body(PayNL.Options.to_post_map(options))
    |> post
    |> process_response
  end

  @doc """
  Extracts the payment reference payment url and transaction id from a transaction request.
  """
  @spec extract_transaction_id_and_payment_url({:ok, data :: map}) :: {:ok, %PayNL.TransActionRequest{}} | {:error, any}
  def extract_transaction_id_and_payment_url(
        {
          :ok,
          %{
            "request" => %{
              "result" => "1"
            },
            "transaction" => %{
              "paymentReference" => wire_transfer_id,
              "paymentURL" => url,
              "transactionId" => transaction_id
            }
          }
        }
      ),
      do: {:ok, %PayNL.TransActionRequest{transaction_id: transaction_id, url: url, wire_transfer_id: wire_transfer_id}}
  def extract_transaction_id_and_payment_url(
        {
          :ok,
          %{
            "request" => %{
              "errorMessage" => message
            }
          }
        }
      ), do: {:error, message}
  def extract_transaction_id_and_payment_url(error), do: error

  @spec process_response({:ok, response :: %Maxwell.Conn{}}) :: {:ok, map} | {:error, any}
  defp process_response({:ok, %Maxwell.Conn{status: 401}}), do: {:error, :invalid_api_token_or_service_id}
  defp process_response({:ok, %Maxwell.Conn{status: 200, resp_body: body}}), do: {:ok, body}
  defp process_response({:error, _} = error), do: error
end
