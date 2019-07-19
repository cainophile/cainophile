defmodule Cainophile.Adapters.Postgres.AdapterBehaviour do
  @callback init(config :: term) ::
              {:ok, %Cainophile.Adapters.Postgres.State{}} | {:stop, reason :: binary}
end
