defmodule PayNL.PaymentOptions do
  @moduledoc """
  This module takes care of parsing  the payment options that are returned from pay.nl
  It will combine information from a deeply nested json feed back to a struct
  """

  defmodule Profile do
    @moduledoc """
    This module provides a simple struct for profiles
    """

    defmodule Option do
      @moduledoc """
      This module provides a simple struct for the profile options
      """

      defstruct [:active, :id, :image_url, :name, :visible_name]
    end
    defstruct [
      :active,
      :costs_fixed,
      :costs_percentage,
      :countries,
      :id,
      :image_url,
      :name,
      :options,
      :payment_method_id,
      :visible_name,
    ]

    @spec json_to_struct({id :: String.t, json :: map}) :: {integer, %PayNL.PaymentOptions.Profile{}}
    def json_to_struct({id, json}) do
      {
        String.to_integer(id),
        %Profile{
          costs_fixed: String.to_integer(json["costsFixed"]),
          costs_percentage: String.to_integer(json["costsPercentage"]),
          countries: Map.keys(json["countries"]),
          id: String.to_integer(json["id"]),
          name: json["name"],
          visible_name: json["visibleName"]
        }
      }
    end
  end

  # check payment_profiles for id, and countries
  # use country_option_list to find country, and then the id. parse all the data and merge with payment profile
  @base_image_path "https://admin.pay.nl/images"

  @spec process_results({:ok, results :: map}) :: {:ok, map} | {:error, any}
  def process_results(
        {:ok, %{"countryOptionList" => country_option_list, "paymentProfiles" => payment_profiles}}
      ) do

    result =
      payment_profiles
      |> Enum.map(&PayNL.PaymentOptions.Profile.json_to_struct/1)
      |> Enum.map(&(enrich_info(&1, country_option_list)))
      |> Enum.map(fn {_id, profile} -> profile end)

    {:ok, result}
  end
  def process_results(error), do: error

  defp enrich_info({id, %PayNL.PaymentOptions.Profile{} = profile}, info) do
    country =
      profile
      |> Map.get(:countries)
      |> List.first

    payment_options =
      info
      |> Map.get(country)
      |> Map.get("paymentOptionList")
      |> Map.get("#{id}")

    profile =
      profile
      |> Map.put(:image_url, @base_image_path <> payment_options["path"] <> payment_options["img"])
      |> Map.put(:payment_method_id, String.to_integer(payment_options["paymentMethodId"]))
      |> Map.put(:active, payment_options["state"] == 1)
      |> add_sub_options(payment_options["paymentOptionSubList"])

    {id, profile}
  end

  @spec add_sub_options(
          profile :: %PayNL.PaymentOptions.Profile{},
          sub_options :: String.t
        ) :: %PayNL.PaymentOptions.Profile{}
  defp add_sub_options(%PayNL.PaymentOptions.Profile{} = profile, ""), do: profile
  defp add_sub_options(%PayNL.PaymentOptions.Profile{} = profile, sub_options) do
    mapped =
      Enum.map(
        sub_options,
        fn {_key, info} ->
          %PayNL.PaymentOptions.Profile.Option{
            id: info["id"],
            name: info["name"],
            visible_name: info["visibleName"],
            image_url: @base_image_path <> info["path"] <> info["img"],
            active: info["state"] == "1"
          }
        end
      )
    Map.put(profile, :options, mapped)
  end
end

