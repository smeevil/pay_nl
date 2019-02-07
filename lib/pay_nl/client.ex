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
  Will request all available payment options at pay.nl that are associated with the account
  """
  @spec get_payment_options({:ok, %PayNL.TransactionOptions{}} | %PayNL.TransactionOptions{} | {:error, any}) :: {
                                                                                                                   :ok,
                                                                                                                   map
                                                                                                                 } | {
                                                                                                                   :error,
                                                                                                                   any()
                                                                                                                 }
  def get_payment_options({:ok, %PayNL.TransactionOptions{} = options}), do: get_payment_options(options)
  def get_payment_options({:error, _} = error), do: error
  def get_payment_options(%PayNL.TransactionOptions{} = options) do
    "/v13/Transaction/getServicePaymentOptions/json?serviceID=#{options.service_id}&token=#{options.api_token}"
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
    "/v13/Transaction/getBanks/json"
    |> new
    |> get
    |> process_response
    |> PayNL.Bank.json_to_struct
  end

  @doc"""
  This call will prepare a payment at pay.nl and returns a redirect url to send the client to confirm payment.
  """
  @spec start_transaction(options :: %PayNL.TransactionOptions{}) :: {:ok, %PayNL.TransActionRequest{}}
  def start_transaction(%PayNL.TransactionOptions{} = options) do
    "/v13/Transaction/start/json"
    |> new
    |> put_req_body(PayNL.TransactionOptions.to_post_map(options))
    |> post
    |> process_response
  end

  @doc"""
  Capture a payment directly from the bank account
  """
  @spec capture_payment(options :: %PayNL.CaptureOptions{}) :: {:ok, any}
  def capture_payment(%PayNL.CaptureOptions{} = options) do
    "/v3/DirectDebit/debitAdd/json"
    |> new
    |> put_req_body(PayNL.CaptureOptions.to_post_map(options))
    |> post
    |> process_response
  end

  @doc"""
  Retrieves the transaction details of a given transaction at pay.nl
  """
  @spec get_transaction_details(options :: %PayNL.TransactionOptions{}, transaction_id :: String.t) :: {:ok, map} | {
    :error,
    any
  }
  def get_transaction_details(options, transaction_id) do
    "/v13/Transaction/info/json?serviceID=#{options.service_id}&token=#{options.api_token}&transactionId=#{
      transaction_id
    }"
    |> new
    |> get
    |> process_response
  end

  @spec get_mandate_details(options :: %PayNL.TransactionOptions{}, mandate :: String.t) :: {:ok, map} | {:error, any}
  def get_mandate_details(options, mandate) do
    "/v3/DirectDebit/info/json?mandateId=#{mandate}"
    |> new
    |> put_req_header("Authorization", "Basic " <> Base.encode64("#{options.token_id}:#{options.api_token}"))
    |> get
    |> process_response
  end

  @spec cancel_capture(options :: %PayNL.TransactionOptions{}, mandate :: String.t) :: {:ok, map} | {:error, any}
  def cancel_capture(options, mandate) do
    "/v3/DirectDebit/delete/json?mandateId=#{mandate}"
    |> new
    |> put_req_header("Authorization", "Basic " <> Base.encode64("#{options.token_id}:#{options.api_token}"))
    |> get
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

  @doc """
  Extracts the payment mandate payment from a capture request.
  """
  @spec extract_mandate({:ok, data :: map}) :: {:ok, %PayNL.CaptureRequest{}} | {:error, any}
  def extract_mandate(
        {
          :ok,
          %{
            "request" => %{
              "result" => "1"
            },
            "result" => mandate
          }
        }
      ),
      do: {:ok, %PayNL.CaptureRequest{mandate: mandate}}
  def extract_mandate(
        {
          :ok,
          %{
            "request" => %{
              "errorMessage" => message
            }
          }
        }
      ), do: {:error, message}

  def extract_success_or_error({:ok, %{"request" => %{"result" => "1"}}}), do: {:ok, :success}
  def extract_success_or_error({:ok, %{"request" => %{"errorMessage" => error}}}), do: {:error, error}

  def extract_payment_status_from_payment_details(
        {:ok, %{"paymentDetails" => %{"state" => state} = _payment_details}}
      ) do
    result = case state do
      "-51" -> :cancel
      "-63" -> :denied
      "-71" -> :chargeback
      "-80" -> :expired
      "-81" -> :refund
      "-82" -> :partial_refund
      "-90" -> :cancel
      "20" -> :pending
      "25" -> :pending
      "50" -> :pending
      "80" -> :partial_payment
      "85" -> :verify
      "90" -> :pending
      "95" -> :authorize
      "100" -> :paid
    end
    {:ok, result}
  end
  def extract_payment_status_from_payment_details(_error), do: {:error, :invalid_payment_details}

  @spec process_response({:ok, response :: %Maxwell.Conn{}}) :: {:ok, map} | {:error, any}
  defp process_response({:ok, %Maxwell.Conn{status: 401}}), do: {:error, :invalid_api_token_or_service_id}
  defp process_response({:ok, %Maxwell.Conn{status: 200, resp_body: body}}), do: {:ok, body}
  defp process_response({:ok, %Maxwell.Conn{status: _, resp_body: body}}), do: {:error, body}
  defp process_response({:error, message, _maxwell_conn}), do: {:error, message}
  defp process_response({:error, _} = error), do: error

end
