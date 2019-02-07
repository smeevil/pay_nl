defmodule PayNL.TransactionOptions do
  @moduledoc """
  This module will validate and format all options that can be passed to pay.nl
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "options" do
    field :amount_in_cents, :integer
    field :api_token, :string
    field :token_id, :string
    field :currency, :string, default: "EUR"
    field :notification_url, :string
    field :remote_ip, :string
    field :return_url, :string
    field :service_id, :string

    field :bank_account_holder, :string
    field :bank_account_number, :string

    field :custom_data, :string
    field :description, :string
    field :locale, :string, default: "EN"
    field :payment_option_id, :integer
    field :payment_provider, :string
    field :reminder_email_template_id, :integer
    field :send_reminder_email, :boolean, default: false
    field :test, :boolean, default: false
  end

  @required_fields [:amount_in_cents, :api_token, :currency, :notification_url, :remote_ip, :return_url, :service_id, :token_id]
  @optional_fields [
    :custom_data,
    :description,
    :payment_option_id,
    :payment_provider,
    :reminder_email_template_id,
    :send_reminder_email,
    :test,
    :locale
  ]

  @field_mappings [
    amount_in_cents: "amount",
    return_url: "finishUrl",
    remote_ip: "ipAddress",
    service_id: "serviceId",
    api_token: "token",
    currency: "transaction[currency]",
    description: "transaction[description]",
    payment_option_id: "paymentOptionId",
    custom_data: "statsData[extra1]",
    notification_url: "transaction[orderExchangeUrl]",
    test: "testMode",
    description: "transaction[description]",
    send_reminder_email: "transaction[sendReminderEmail]",
    reminder_email_template_id: "transaction[reminderMailTemplateId]",
    locale: "enduser[language]",
  ]

  @payment_options %{
    ideal: 10,
    credit_card: 11,
    paypal: 138,
    mr_cash: 436
  }

  @doc """
  Use this to create the PayNL.TransactionOptions struct which will validate all options given.
  """
  @spec create(params :: map | list) :: {:ok, %PayNL.TransactionOptions{}} | {:error, list}
  def create(params \\ %{})
  def create(params) when is_list(params), do: create(Enum.into(params, %{}))
  def create(params) do
    case payment_changeset(%PayNL.TransactionOptions{}, params) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, Enum.map(changeset.errors, fn ({field, {msg, _}}) -> {field, msg} end)}
    end
  end

  @doc """
  Use this if you only need to validate / use credentials for your paynl account
  """
  @spec credentials(params :: map | list) :: {:ok, %PayNL.TransactionOptions{}} | {:error, Ecto.Changeset.t}
  def credentials(params \\ %{})
  def credentials(params) when is_list(params), do: credentials(Enum.into(params, %{}))
  def credentials(params) do
    case credentials_changeset(params) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, Enum.map(changeset.errors, fn ({field, {msg, _}}) -> {field, msg} end)}
    end
  end

  @spec credentials_changeset(params :: map) :: Ecto.Changeset.t
  defp credentials_changeset(params) do
    params = add_defaults(params)

    %PayNL.TransactionOptions{}
    |> cast(params, [:api_token, :service_id, :token_id])
    |> validate_required(
         :token_id,
         message: ~s[has not been set, either pass it along with the params in this function as :token_id, alternatively you can pass it by defining an env var 'PAY_NL_TOKEN_ID=AT-xxxx-xxxx' or in you config add 'config :pay_nl, token_id: "AT-xxxx-xxxx"']
       )
    |> validate_required(
         :api_token,
         message: ~s[has not been set, either pass it along with the params in this function as :api_token, alternatively you can pass it by defining an env var 'PAY_NL_API_TOKEN=my_api_token' or in you config add 'config :pay_nl, api_token: "my_api_token"']
       )
    |> validate_required(
         :service_id,
         message: ~s[has not been set, either pass it along with the params in this function as :service_id, alternatively you can pass it by defining an env var 'PAY_NL_SERVICE_ID=my_service_id' or in you config add 'config :pay_nl, service_id: "my_service_id"']
       )
  end

  @spec payment_changeset(struct :: %PayNL.TransactionOptions{}, params :: map) :: Ecto.Changeset.t
  defp payment_changeset(struct, params) do
    params = params
             |> add_defaults
             |> maybe_cast_payment_provider_to_string

    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(
         :token_id,
         message: ~s[has not been set, either pass it along with the params in this function as :token_id, alternatively you can pass it by defining an env var 'PAY_NL_TOKEN_ID=AT-xxxx-xxxx' or in you config add 'config :pay_nl, token_id: "AT-xxxx-xxxx"']
       )
    |> validate_required(
         :api_token,
         message: ~s[has not been set, either pass it along with the params in this function as :api_token, alternatively you can pass it by defining an env var 'PAY_NL_API_TOKEN=my_api_token' or in you config add 'config :pay_nl, api_token: "my_api_token"']
       )
    |> validate_required(
         :service_id,
         message: ~s[has not been set, either pass it along with the params in this function as :service_id, alternatively you can pass it by defining an env var 'PAY_NL_SERVICE_ID=my_service_id' or in you config add 'config :pay_nl, api_token: "my_service_id"']
       )
    |> validate_required(@required_fields)
    |> validate_inclusion(
         :payment_provider,
         string_keys(@payment_options),
         message: "should be one of #{
           @payment_options
           |> Map.keys()
           |> Enum.join(", ")
         }"
       )
    |> set_payment_provider_option
  end

  @spec add_defaults(params :: map) :: map
  defp add_defaults(params) do
    params
    |> Map.put_new(:service_id, System.get_env("PAY_NL_SERVICE_ID") || Application.get_env(:pay_nl, :service_id))
    |> Map.put_new(:api_token, System.get_env("PAY_NL_API_TOKEN") || Application.get_env(:pay_nl, :api_token))
    |> Map.put_new(:token_id, System.get_env("PAY_NL_TOKEN_ID") || Application.get_env(:pay_nl, :token_id))
    |> Map.put_new(:return_url, Application.get_env(:pay_nl, :return_url))
    |> Map.put_new(:notification_url, Application.get_env(:pay_nl, :notification_url))
  end

  @spec set_payment_provider_option(changeset :: Ecto.Changeset.t) :: Ecto.Changeset.t
  def set_payment_provider_option(
        %{
          valid?: true,
          changes: %{
            payment_provider: payment_provider
          }
        } = changeset
      ) do
    Ecto.Changeset.put_change(changeset, :payment_option_id, @payment_options[String.to_atom(payment_provider)])
  end
  def set_payment_provider_option(changeset), do: changeset

  @spec maybe_cast_payment_provider_to_string(params :: map) :: map
  defp maybe_cast_payment_provider_to_string(%{payment_provider: payment_provider} = params)
       when is_atom(payment_provider) do
    Map.put(params, :payment_provider, Atom.to_string(payment_provider))
  end
  defp maybe_cast_payment_provider_to_string(params), do: params

  @spec string_keys(map) :: list
  defp string_keys(map), do: Enum.map(map, fn {k, _v} -> to_string(k) end)

  @spec to_post_map(options :: %PayNL.TransactionOptions{}) :: map
  def to_post_map(%PayNL.TransactionOptions{} = options) do
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
