defmodule Cainophile.Adapters.PostgresTest do
  use ExUnit.Case
  import Mox
  alias Cainophile.Adapters.{Postgres, Postgres.State}

  doctest Cainophile.Adapters.Postgres

  setup_all do
    Mox.defmock(PostgresMock, for: Cainophile.Adapters.Postgres.AdapterBehaviour)
    :ok
  end

  # Make sure mocks are verified when the test exits
  setup :set_mox_global

  setup do
    test_runner_pid = self()

    expect(PostgresMock, :init, fn config ->
      {:ok, %State{connection: self(), config: config, subscribers: [test_runner_pid]}}
    end)

    {:ok, pid} = Postgres.start_link(postgres_adapter: PostgresMock)
    %{processor: pid}
  end

  setup :verify_on_exit!

  test "allows subscribing to changes by pid", %{processor: processor} do
    assert {:ok, subscribers} = Postgres.subscribe(processor, self())
    assert self() in subscribers
  end
end
