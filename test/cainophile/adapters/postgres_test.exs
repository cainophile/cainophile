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

  test "allows subscribing to changes by function", %{processor: processor} do
    test_fun = fn _changes ->
      "Hello world"
    end

    assert {:ok, subscribers} = Postgres.subscribe(processor, test_fun)
    assert test_fun in subscribers
  end

  # test "allows subscribing to changes by pid", %{processor: processor} do
  #   send(
  #     processor,
  #     {:epgsql, self(),
  #      {:x_log_data, 0, 0,
  #       <<66, 0, 0, 0, 2, 167, 244, 168, 128, 0, 2, 48, 246, 88, 88, 213, 242, 0, 0, 2, 107>>}}
  #   )

  #   assert_receive(%PgoutputDecoder.Messages.Begin{
  #     commit_timestamp: _,
  #     final_lsn: {2, 2_817_828_992},
  #     xid: 619
  #   })
  # end
end
