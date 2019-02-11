defmodule PayNL.Client do
  @moduledoc """
  This module wraps the json api of Pay.NL
  """

  defp json_post(path, options \\ nil, data \\ %{}) do
    IO.puts "Starting request to https://rest-api.pay.nl#{path}"
    auth_header =
      if options == nil,
         do: [],
         else: [Authorization: "Basic #{Base.encode64("#{options.token_id}:#{options.api_token}")}"]

    HTTPotion.post(
      "https://rest-api.pay.nl#{path}",
      [
        body: Poison.encode!(data),
        headers: ["Content-Type": "application/json"] ++ auth_header
      ]
    )
  end

  @doc """
  Will request all available payment options at pay.nl that are associated with the account
  """
  @spec get_payment_options({:ok, %PayNL.TransactionOptions{}} | %PayNL.TransactionOptions{} | {:error, any})
        :: {:ok, map} | {:error, any()}
  def get_payment_options({:ok, %PayNL.TransactionOptions{} = options}), do: get_payment_options(options)
  def get_payment_options({:error, _} = error), do: error
  def get_payment_options(%PayNL.TransactionOptions{} = options) do
    "/v13/Transaction/getServicePaymentOptions/json"
    |> json_post(options, %{serviceId: options.service_id, token: options.api_token})
    |> process_response
    |> PayNL.PaymentOptions.process_results
  end

  @doc """
  Will request all supported iDeal banks and their current availability
  """
  @spec get_banks :: {:ok, list(%PayNL.Bank{})} | {:error, binary}
  def get_banks do
    "/v13/Transaction/getBanks/json"
    |> json_post()
    |> process_response
    |> PayNL.Bank.json_to_struct
  end

  @doc"""
  This call will prepare a payment at pay.nl and returns a redirect url to send the client to confirm payment.
  """
  @spec start_transaction(options :: %PayNL.TransactionOptions{}) :: {:ok, %PayNL.TransActionRequest{}}
  def start_transaction(%PayNL.TransactionOptions{} = options) do
    payload = PayNL.TransactionOptions.to_post_map(options)
    "/v13/Transaction/start/json"
    |> json_post(options, payload)
    |> process_response
  end

  @doc"""
  Capture a payment directly from the bank account
  """
  @spec capture_payment(options :: %PayNL.CaptureOptions{}) :: {:ok, any}
  def capture_payment(%PayNL.CaptureOptions{} = options) do
    payload = PayNL.CaptureOptions.to_post_map(options)
    "/v3/DirectDebit/debitAdd/json"
    |> json_post(options, payload)
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
    "/v13/Transaction/info/json"
    |> json_post(options, %{serviceId: options.service_id, token: options.api_token, transactionId: transaction_id})
    |> process_response
  end

  @spec get_mandate_details(options :: %PayNL.TransactionOptions{}, mandate :: String.t) :: {:ok, map} | {:error, any}
  def get_mandate_details(options, mandate) do
    "/v3/DirectDebit/info/json"
    |> json_post(options, %{mandateId: mandate})
    |> process_response
  end

  @spec cancel_capture(options :: %PayNL.TransactionOptions{}, mandate :: String.t) :: {:ok, map} | {:error, any}
  def cancel_capture(options, mandate) do
    "/v3/DirectDebit/delete/json"
    |> json_post(options, %{mandateId: mandate})
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

  def extract_success_or_error(
        {
          :ok,
          %{
            "request" => %{
              "result" => "1"
            }
          }
        }
      ), do: {:ok, :success}
  def extract_success_or_error(
        {
          :ok,
          %{
            "request" => %{
              "errorMessage" => error
            }
          }
        }
      ), do: {:error, error}

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


  def extract_payment_status_from_capture_details(
        {
          :ok,
          %{
            "request" => %{
              "errorId" => error_id
            }
          }
        }
      ) when error_id != "" do
    result = case error_id do
      "100" -> :general_error
      "101" -> :invalid_amount
      "102" -> :date_to_early
      "103" -> :invalid_interval
      "104" -> :interval_value_has_been_reached
      "105" -> :interval_must_be_higher_then_zero
      "201" -> :cant_start_on_own_bank_account
      "202" -> :invalid_service_or_not_enabled
      "203" -> :exceeds_max_order_amount
      "204" -> :back_account_blacklisted
      "205" -> :max_orders_for_bank_account_reached
      "206" -> :account_reached_max_debit
      "207" -> :date_to_early
      "403" -> :access_denied
      "404" -> :invalid_value_or_parameter
      "405" -> :invalid_input
      "500" -> :internal_error
    end
    {:error, result}
  end

  def extract_payment_status_from_capture_details(
        {
          :ok,
          %{
            "result" => %{
              "directDebit" => ""
            }
          }
        }
      ), do: {:ok, :scheduled}

  def extract_payment_status_from_capture_details(
        {
          :ok,
          %{
            "result" => %{
              "directDebit" => [%{"statusCode" => state}]
            }
          }
        }
      ) do
    result = case state do
      "100" -> :success
      "94" -> :processing
      "106" -> :reverted
      "91" -> :pending
      "526" -> :batched
      "97" -> :declined_by_paynl
      "103" -> :removed
      "127" -> :declined_by_bank
    end
    {:ok, result}
  end
  def extract_payment_status_from_capture_details(error) do
    IO.inspect(error, label: "capture details")
    {:error, :invalid_capture_details}
  end

  @spec process_response(response :: %HTTPotion.Response{}) :: {:ok, map} | {:error, any}
  defp process_response(%HTTPotion.Response{status_code: 401}), do: {:error, :invalid_api_token_or_service_id}
  defp process_response(%HTTPotion.Response{status_code: 200, body: body}), do: {:ok, Poison.decode!(body)}
  defp process_response(%HTTPotion.Response{status_code: _, body: body}), do: {:error, body}
  defp process_response(%HTTPotion.ErrorResponse{message: message}), do: {:error, message}
  defp process_response(error), do: error

end
