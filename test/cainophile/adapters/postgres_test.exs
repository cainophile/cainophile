defmodule Cainophile.Adapters.PostgresTest do
  use ExUnit.Case
  import Mox
  alias Cainophile.Adapters.{Postgres, Postgres.State}

  alias Cainophile.Changes.{
    Transaction,
    NewRecord,
    UpdatedRecord,
    DeletedRecord,
    TruncatedRelation
  }

  # TODO: Ideally abstract this out so we can mock out pgdecoder with higher level constructs
  @insert_txn_bins [
    # Begin
    <<66, 0, 0, 0, 2, 167, 249, 2, 56, 0, 2, 49, 12, 168, 58, 245, 78, 0, 0, 2, 157>>,
    # Type
    <<89, 0, 0, 128, 52, 112, 117, 98, 108, 105, 99, 0, 101, 120, 97, 109, 112, 108, 101, 95, 116,
      121, 112, 101, 0>>,
    # Relation
    <<82, 0, 0, 96, 0, 112, 117, 98, 108, 105, 99, 0, 102, 111, 111, 0, 102, 0, 3, 1, 98, 97, 114,
      0, 0, 0, 0, 25, 255, 255, 255, 255, 1, 105, 100, 0, 0, 0, 0, 23, 255, 255, 255, 255, 1, 99,
      117, 115, 116, 111, 109, 95, 116, 121, 112, 101, 0, 0, 0, 128, 52, 255, 255, 255, 255>>,
    # Insert
    <<73, 0, 0, 96, 0, 78, 0, 3, 116, 0, 0, 0, 12, 98, 97, 122, 98, 97, 114, 49, 50, 51, 52, 53,
      56, 116, 0, 0, 0, 3, 53, 54, 56, 116, 0, 0, 0, 8, 40, 97, 98, 99, 100, 101, 102, 41>>,
    # Commit
    <<67, 0, 0, 0, 0, 2, 167, 249, 2, 56, 0, 0, 0, 2, 167, 249, 2, 104, 0, 2, 49, 12, 168, 58,
      245, 78>>
  ]

  @insert_and_update_txn_bins [
    # Begin
    <<66, 0, 0, 0, 2, 167, 249, 128, 144, 0, 2, 49, 15, 72, 201, 23, 156, 0, 0, 2, 173>>,
    # Type
    <<89, 0, 0, 128, 52, 112, 117, 98, 108, 105, 99, 0, 101, 120, 97, 109, 112, 108, 101, 95, 116,
      121, 112, 101, 0>>,
    # Relation
    <<82, 0, 0, 96, 0, 112, 117, 98, 108, 105, 99, 0, 102, 111, 111, 0, 102, 0, 3, 1, 98, 97, 114,
      0, 0, 0, 0, 25, 255, 255, 255, 255, 1, 105, 100, 0, 0, 0, 0, 23, 255, 255, 255, 255, 1, 99,
      117, 115, 116, 111, 109, 95, 116, 121, 112, 101, 0, 0, 0, 128, 52, 255, 255, 255, 255>>,
    # Insert
    <<73, 0, 0, 96, 0, 78, 0, 3, 116, 0, 0, 0, 12, 98, 97, 122, 98, 97, 114, 49, 50, 51, 52, 54,
      54, 116, 0, 0, 0, 3, 53, 56, 51, 116, 0, 0, 0, 8, 40, 97, 98, 99, 100, 101, 102, 41>>,
    # Update (with old data)
    <<85, 0, 0, 96, 0, 79, 0, 3, 116, 0, 0, 0, 12, 98, 97, 122, 98, 97, 114, 49, 50, 51, 52, 54,
      54, 116, 0, 0, 0, 3, 53, 56, 51, 116, 0, 0, 0, 8, 40, 97, 98, 99, 100, 101, 102, 41, 78, 0,
      3, 116, 0, 0, 0, 7, 99, 104, 97, 110, 103, 101, 100, 116, 0, 0, 0, 3, 53, 56, 51, 116, 0, 0,
      0, 8, 40, 97, 98, 99, 100, 101, 102, 41>>,
    # Commit
    <<67, 0, 0, 0, 0, 2, 167, 249, 128, 144, 0, 0, 0, 2, 167, 249, 128, 192, 0, 2, 49, 15, 72,
      201, 23, 156>>
  ]

  @delete_txn_bins [
    # Begin
    <<66, 0, 0, 0, 2, 167, 249, 128, 144, 0, 2, 49, 15, 72, 201, 23, 156, 0, 0, 2, 173>>,
    # Type
    <<89, 0, 0, 128, 52, 112, 117, 98, 108, 105, 99, 0, 101, 120, 97, 109, 112, 108, 101, 95, 116,
      121, 112, 101, 0>>,
    # Relation
    <<82, 0, 0, 96, 0, 112, 117, 98, 108, 105, 99, 0, 102, 111, 111, 0, 102, 0, 3, 1, 98, 97, 114,
      0, 0, 0, 0, 25, 255, 255, 255, 255, 1, 105, 100, 0, 0, 0, 0, 23, 255, 255, 255, 255, 1, 99,
      117, 115, 116, 111, 109, 95, 116, 121, 112, 101, 0, 0, 0, 128, 52, 255, 255, 255, 255>>,
    # Delete
    <<68, 0, 0, 96, 0, 79, 0, 3, 116, 0, 0, 0, 7, 99, 104, 97, 110, 103, 101, 100, 116, 0, 0, 0,
      3, 53, 56, 51, 116, 0, 0, 0, 8, 40, 97, 98, 99, 100, 101, 102, 41>>,
    # Commit
    <<67, 0, 0, 0, 0, 2, 167, 249, 128, 144, 0, 0, 0, 2, 167, 249, 128, 192, 0, 2, 49, 15, 72,
      201, 23, 156>>
  ]

  @truncate_txn_bins [
    # Begin
    <<66, 0, 0, 0, 2, 167, 249, 128, 144, 0, 2, 49, 15, 72, 201, 23, 156, 0, 0, 2, 173>>,
    # Type
    <<89, 0, 0, 128, 52, 112, 117, 98, 108, 105, 99, 0, 101, 120, 97, 109, 112, 108, 101, 95, 116,
      121, 112, 101, 0>>,
    # Relation
    <<82, 0, 0, 96, 0, 112, 117, 98, 108, 105, 99, 0, 102, 111, 111, 0, 102, 0, 3, 1, 98, 97, 114,
      0, 0, 0, 0, 25, 255, 255, 255, 255, 1, 105, 100, 0, 0, 0, 0, 23, 255, 255, 255, 255, 1, 99,
      117, 115, 116, 111, 109, 95, 116, 121, 112, 101, 0, 0, 0, 128, 52, 255, 255, 255, 255>>,
    # Truncate
    <<84, 0, 0, 0, 1, 0, 0, 0, 96, 0>>,
    # Commit
    <<67, 0, 0, 0, 0, 2, 167, 249, 128, 144, 0, 0, 0, 2, 167, 249, 128, 192, 0, 2, 49, 15, 72,
      201, 23, 156>>
  ]

  doctest Cainophile.Adapters.Postgres

  setup_all do
    Mox.defmock(PostgresMock, for: Cainophile.Adapters.Postgres.AdapterBehaviour)
    :ok
  end

  setup :set_mox_global
  setup :create_mocks

  setup do
    {:ok, pid} = Postgres.start_link(postgres_adapter: PostgresMock)

    %{processor: pid}
  end

  # Make sure mocks are verified when the test exits
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

  describe "Change handling" do
    setup %{processor: processor} do
      {:ok, _subscribers} = Postgres.subscribe(processor, self())

      :ok
    end

    test "publishes insert transaction to pid subscribers", %{processor: processor} do
      for msg <- generate_insert_transaction(), do: send(processor, msg)

      assert_receive(%Transaction{
        commit_timestamp: timestamp,
        changes: [
          %NewRecord{
            relation: {"public", "foo"},
            record: %{
              "bar" => "bazbar123458",
              "id" => "568",
              "custom_type" => "(abcdef)"
            }
          }
        ]
      })

      {:ok, expected_dt, _} = DateTime.from_iso8601("2019-07-19T19:39:45Z")

      # Use inspect as we don't care about microseconds
      assert inspect(timestamp) == inspect(expected_dt)
    end

    test "publishes insert+update transaction to pid subscribers", %{processor: processor} do
      for msg <- generate_insert_and_update_transaction(), do: send(processor, msg)

      assert_receive(%Transaction{
        commit_timestamp: timestamp,
        changes: [
          %NewRecord{
            relation: {"public", "foo"},
            record: %{
              "bar" => "bazbar123466",
              "id" => "583",
              "custom_type" => "(abcdef)"
            }
          },
          %UpdatedRecord{
            relation: {"public", "foo"},
            old_record: %{
              "bar" => "bazbar123466",
              "id" => "583",
              "custom_type" => "(abcdef)"
            },
            record: %{
              "bar" => "changed",
              "id" => "583",
              "custom_type" => "(abcdef)"
            }
          }
        ]
      })

      {:ok, expected_dt, _} = DateTime.from_iso8601("2019-07-19T22:47:48Z")

      # Use inspect as we don't care about microseconds
      assert inspect(timestamp) == inspect(expected_dt)
    end

    test "publishes delete transaction to pid subscribers", %{processor: processor} do
      for msg <- generate_delete_transaction(), do: send(processor, msg)

      assert_receive(%Transaction{
        commit_timestamp: timestamp,
        changes: [
          %DeletedRecord{
            relation: {"public", "foo"},
            old_record: %{
              "bar" => "changed",
              "id" => "583",
              "custom_type" => "(abcdef)"
            }
          }
        ]
      })

      {:ok, expected_dt, _} = DateTime.from_iso8601("2019-07-19T22:47:48Z")

      # Use inspect as we don't care about microseconds
      assert inspect(timestamp) == inspect(expected_dt)
    end

    test "publishes truncate transaction to pid subscribers", %{processor: processor} do
      for msg <- generate_truncate_transaction(), do: send(processor, msg)

      assert_receive(%Transaction{
        commit_timestamp: timestamp,
        changes: [
          %TruncatedRelation{
            relation: {"public", "foo"}
          }
        ]
      })

      {:ok, expected_dt, _} = DateTime.from_iso8601("2019-07-19T22:47:48Z")

      # Use inspect as we don't care about microseconds
      assert inspect(timestamp) == inspect(expected_dt)
    end

    test "acknowledges changes on commit", %{processor: processor} do
      test_runner_pid = self()

      expect(PostgresMock, :acknowledge_lsn, fn connection, lsn_tup ->
        assert connection == test_runner_pid
        assert lsn_tup == {2, 2_818_146_496}

        send(test_runner_pid, {:acknowledged, connection, lsn_tup})
        :ok
      end)

      for msg <- generate_truncate_transaction(), do: send(processor, msg)

      assert_receive({:acknowledged, ^test_runner_pid, {2, 2_818_146_496}})
    end
  end

  defp generate_insert_transaction() do
    for bin <- @insert_txn_bins, do: generate_epgsql_message(bin)
  end

  defp generate_insert_and_update_transaction() do
    for bin <- @insert_and_update_txn_bins, do: generate_epgsql_message(bin)
  end

  defp generate_delete_transaction() do
    for bin <- @delete_txn_bins, do: generate_epgsql_message(bin)
  end

  defp generate_truncate_transaction() do
    for bin <- @truncate_txn_bins, do: generate_epgsql_message(bin)
  end

  defp generate_epgsql_message(binary) do
    {:epgsql, self(), {:x_log_data, 0, 0, binary}}
  end

  defp create_mocks(ctx) do
    test_runner_pid = self()

    expect(PostgresMock, :init, fn config ->
      {:ok, %State{connection: test_runner_pid, config: config, subscribers: []}}
    end)

    stub(PostgresMock, :acknowledge_lsn, fn _connection, _lsn_tup ->
      :ok
    end)

    ctx
  end
end
