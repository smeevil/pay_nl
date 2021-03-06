defmodule PayNL.Supervisor do
  @moduledoc """
  This module starts the supervisor which makes sure that the options cache is available
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(PayNL.TransactionOptionsCache, []),
    ]

    opts = [strategy: :one_for_one, name: PayNL.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
