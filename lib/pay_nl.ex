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

  @spec payment_options :: map
  def payment_options, do: GenServer.call(PayNL.OptionsCache, {:payment_options})

  @spec payment_options_for_country(country :: String.t) :: {:ok, list(%PayNL.Options{})}
  def payment_options_for_country(country) do
    PayNL.OptionsCache
    |> GenServer.call({:payment_options})
    |> options_for_country(country)
  end

  @spec request_payment(options :: map | %PayNL.Options{}) :: {:ok, %PayNL.TransActionRequest{}} | {:error, binary}
  def request_payment(options) when is_list(options), do: request_payment(Enum.into(options, %{}))
  def request_payment(%PayNL.Options{} = options) do
    options
    |> PayNL.Client.start_transaction
    |> PayNL.Client.extract_transaction_id_and_payment_url
  end
  def request_payment(options) when is_map(options) do
    case PayNL.Options.create(options) do
      {:ok, options} -> request_payment(options)
      error -> error
    end
  end

  @spec options_for_country({:ok, list(%PayNL.Options{})}, country :: String.t) :: {
                                                                                     :ok,
                                                                                     list(%PayNL.Options{}) | {
                                                                                       :error,
                                                                                       String.t
                                                                                     }
                                                                                   }
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
