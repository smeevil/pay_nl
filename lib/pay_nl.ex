defmodule PayNL do
  @moduledoc """
  This module provides all entry points to interact with https://www.pay.nl and allows you to create payment requests.
  """

  defmodule TransActionRequest do
    @moduledoc """
    This module provides a simple struct for transaction request.
    the `wire_transfer_id` can be used as identifier when doing manual payments via a cheque
    """
    defstruct [:url, :transaction_id, :wire_transfer_id]
  end

  defmodule CaptureRequest do
    @moduledoc """
    This module provides a simple struct for capture request.
    """
    defstruct [:mandate]
  end

  @spec payment_options :: map
  def payment_options, do: GenServer.call(PayNL.TransactionOptionsCache, {:payment_options})

  @spec payment_options_for_country(country :: String.t) :: {:ok, list(%PayNL.TransactionOptions{})}
  def payment_options_for_country(country) do
    PayNL.TransactionOptionsCache
    |> GenServer.call({:payment_options})
    |> options_for_country(country)
  end

  @doc """
  Returns the raw transaction details
  """
  @spec get_transaction_details_for(transaction_id :: String.t) :: {:ok, atom} | {:error, String.t}
  def get_transaction_details_for(transaction_id) do
    {:ok, credentials} = PayNL.TransactionOptions.credentials()
    PayNL.Client.get_transaction_details(credentials, transaction_id)
  end

  @doc """
  Returns the payment status of a transaction
  """
  @spec get_payment_status_for(transaction_id :: String.t) :: {:ok, atom} | {:error, String.t}
  def get_payment_status_for(transaction_id) do
    {:ok, credentials} = PayNL.TransactionOptions.credentials()

    credentials
    |> PayNL.Client.get_transaction_details(transaction_id)
    |> PayNL.Client.extract_payment_status_from_payment_details
  end


  @spec request_payment(options :: list | map | %PayNL.TransactionOptions{}) :: {:ok, %PayNL.TransActionRequest{}} | {:error,  any}
  def request_payment(options) when is_list(options), do: request_payment(Enum.into(options, %{}))
  def request_payment(%PayNL.TransactionOptions{} = options) do
    options
    |> PayNL.Client.start_transaction
    |> PayNL.Client.extract_transaction_id_and_payment_url
  end
  def request_payment(options) when is_map(options) do
    case PayNL.TransactionOptions.create(options) do
      {:ok, options} -> request_payment(options)
      error -> error
    end
  end

  def capture_payment(options) when is_list(options), do: capture_payment(Enum.into(options, %{}))
  def capture_payment(%PayNL.CaptureOptions{} = options) do
    options
    |> PayNL.Client.capture_payment()
    |> PayNL.Client.extract_mandate()
  end
  def capture_payment(options) when is_map(options) do
    case PayNL.CaptureOptions.create(options) do
      {:ok, options} -> capture_payment(options)
      error -> error
    end
  end

  @spec cancel_capture(String.t) :: {:ok, atom} | {:error, String.t}
  def cancel_capture(mandate) do
    {:ok, credentials} = PayNL.TransactionOptions.credentials()

    credentials
    |> PayNL.Client.cancel_capture(mandate)
    |> PayNL.Client.extract_success_or_error
  end

  @spec get_mandate_status_for(String.t) :: {:ok, atom} | {:error, String.t}
  def get_mandate_status_for(mandate) do
    {:ok, credentials} = PayNL.TransactionOptions.credentials()

    credentials
    |> PayNL.Client.get_mandate_details(mandate)
    |> PayNL.Client.extract_payment_status_from_capture_details
  end

  @spec options_for_country({:ok, list(%PayNL.TransactionOptions{})}, country :: String.t) ::
          {:ok, list(%PayNL.TransactionOptions{}) | {:error, String.t}}
  defp options_for_country({:ok, options}, country) do
    {
      :ok,
      Enum.filter(
        options,
        fn option -> Enum.member?(option.countries, country) || Enum.member?(option.countries, "ALL") end
      )
    }
  end
  defp options_for_country(error, _country), do: error
end
