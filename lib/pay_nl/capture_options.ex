defmodule PayNL.CaptureOptions do
  @moduledoc """
  This module will validate and format all options that can be passed to pay.nl
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "options" do
    field :amount_in_cents, :integer
    field :api_token, :string
    field :currency, :string, default: "EUR"
    field :notification_url, :string
    field :service_id, :string

    field :bank_account_holder, :string
    field :bank_account_number, :string

    field :custom_data, :string
    field :description, :string
  end

  @required_fields [
    :amount_in_cents,
    :api_token,
    :bank_account_holder,
    :bank_account_number,
    :currency,
    :notification_url,
    :service_id
  ]

  @optional_fields [
    :custom_data,
    :description,
  ]

  @field_mappings [
    amount_in_cents: "amount",
    service_id: "serviceId",
    api_token: "token",
    currency: "currency",
    description: "description",
    custom_data: "extra1",
    notification_url: "exchangeUrl",
    description: "description",
    bank_account_holder: "bankAccountHolder",
    bank_account_number: "bankAccountNumber"
  ]

  @doc """
  Use this to create the PayNL.CaptureOptions struct which will validate all options given.
  """
  @spec create(params :: map | list) :: {:ok, %PayNL.CaptureOptions{}} | {:error, list}
  def create(params \\ %{})
  def create(params) when is_list(params), do: create(Enum.into(params, %{}))
  def create(params) do
    case capture_changeset(%PayNL.CaptureOptions{}, params) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, Enum.map(changeset.errors, fn ({field, {msg, _}}) -> {field, msg} end)}
    end
  end

  @spec capture_changeset(struct :: %PayNL.CaptureOptions{}, params :: map) :: Ecto.Changeset.t
  defp capture_changeset(struct, params) do
    params = add_defaults(params)

    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(
         :api_token,
         message: ~s[has not been set, either pass it along with the params in this function as :api_token, alternatively you can pass it by defining an env var 'PAY_NL_API_TOKEN=my_api_token' or in you config add 'config :pay_nl, api_token: "my_api_token"']
       )
    |> validate_required(
         :service_id,
         message: ~s[has not been set, either pass it along with the params in this function as :service_id, alternatively you can pass it by defining an env var 'PAY_NL_SERVICE_ID=my_service_id' or in you config add 'config :pay_nl, api_token: "my_service_id"']
       )
    |> validate_required(@required_fields)
  end

  @spec add_defaults(params :: map) :: map
  defp add_defaults(params) do
    params
    |> Map.put_new(:service_id, System.get_env("PAY_NL_SERVICE_ID") || Application.get_env(:pay_nl, :service_id))
    |> Map.put_new(:api_token, System.get_env("PAY_NL_API_TOKEN") || Application.get_env(:pay_nl, :api_token))
    |> Map.put_new(:return_url, Application.get_env(:pay_nl, :return_url))
    |> Map.put_new(:notification_url, Application.get_env(:pay_nl, :notification_url))
  end

  @spec to_post_map(options :: %PayNL.CaptureOptions{}) :: map
  def to_post_map(%PayNL.CaptureOptions{} = options) do
    options
    |> Map.from_struct
    |> Map.delete(:__meta__)
    |> process_options(@field_mappings)
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Enum.into(%{})
  end

  @spec process_options(options :: map, mapping :: list({atom, binary}), data :: map) :: map
  defp process_options(options, mapping, data \\ %{})
  defp process_options(_options, [], data), do: data
  defp process_options(options, [{key, mapped} | tail], data) do
    data = case Map.get(options, key) do
      nil -> data
      value -> Map.put(data, mapped, convert_value(value))
    end
    process_options(options, tail, data)
  end

  @spec convert_value(value :: boolean | any) :: true | false | any
  def convert_value(true), do: "1"
  def convert_value(false), do: "0"
  def convert_value(value), do: value
end
