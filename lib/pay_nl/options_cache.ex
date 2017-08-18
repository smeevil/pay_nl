defmodule PayNL.OptionsCache do
  @moduledoc """
  This will start a GenServer that will keep a hot cache for the available payment options that the used account at paynl provides.
  Because of this cache we do not have to live query the paynl servers each time.
  """
  use GenServer

  @spec start_link :: {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, %{}, [name: __MODULE__])
  end

  @spec init(options :: map) :: {:ok, map}
  def init(_options) do
    {:ok, _ref} = :timer.apply_after(100, __MODULE__, :warmup_cache, [])
    {:ok, %{hot_cache: false}}
  end

  def handle_call({:payment_options}, _from, state) do
    if state.hot_cache do
      {:reply, {:ok, state.cache}, state}
    else
      case get_payment_options() do
        {:ok, data} -> {:reply, data, %{hot_cache: true, cache: data}}
        error -> {:reply, error, state}
      end
    end
  end

  def handle_call({:warmup_cache}, _from, state) do
    case get_payment_options() do
      {:ok, data} -> {:reply, :ok, %{hot_cache: true, cache: data}}
      error -> {:reply, error, state}
    end
  end

  @spec warmup_cache :: :ok | {:error, String.t}
  def warmup_cache do
    case GenServer.call(__MODULE__, {:warmup_cache}) do
      :ok -> :ok
      {:error, message} -> IO.puts "ERROR: #{inspect message}"
    end
  end

  @spec get_payment_options :: {:ok, map} | {:error, any()}
  defp get_payment_options,
       do: PayNL.Options.credentials()
           |> PayNL.Client.get_payment_options
end