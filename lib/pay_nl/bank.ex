defmodule PayNL.Bank do
  @moduledoc """
  This module provides a simple struct for the available banks of iDeal
  """
  defstruct  [:available, :image, :id, :issuer_id, :name, :swift]

  @spec json_to_struct({:ok, json :: map}) :: {:ok, list(%PayNL.Bank{})} | {:error, String.t}
  def json_to_struct({:ok, json}), do: {:ok, Enum.map(json, &parse_entry/1)}
  def json_to_struct(error), do: error

  @spec parse_entry(entry :: map) :: %PayNL.Bank{}
  def parse_entry(entry) do
    %PayNL.Bank{
      available: (if entry["available"] == "1", do: true, else: false),
      image: entry["icon"],
      id: String.to_integer(entry["id"]),
      issuer_id: String.to_integer(entry["issuerId"]),
      name: entry["name"],
      swift: entry["swift"]
    }
  end
end