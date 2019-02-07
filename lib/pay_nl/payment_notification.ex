defmodule PayNL.PaymentNotification do
  @moduledoc """
  This module will take care of handling the payment notifications that we receive from pay.nl
  """

  def verify(%{"order_id" => transaction_id}) do
    {:ok, credentials} = PayNL.TransactionOptions.credentials()
    case PayNL.Client.get_transaction_details(credentials, transaction_id) do
      {:ok, %{"request" => %{"result" => "1"}} = details} -> {:ok, details}
      {:ok, %{"request" => %{"result" => "0", "errorMessage" => message}}} -> {:error, message}
      _ -> {:error, "could not verify transaction"}
    end
  end
end
