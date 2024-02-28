defmodule Cainophile.Adapters.Postgres do
  defmodule(State,
    do:
      defstruct(
        config: [],
        connection: nil,
        subscribers: [],
        transaction: nil,
        relations: %{},
        types: %{}
      )
  )

  use GenServer
  require Logger

  alias Cainophile.Adapters.Postgres.Types

  alias Cainophile.Changes.{
    Transaction,
    NewRecord,
    UpdatedRecord,
    DeletedRecord,
    TruncatedRelation
  }

  alias PgoutputDecoder.Messages.{
    Begin,
    Commit,
    Relation,
    Insert,
    Update,
    Delete,
    Truncate,
    Type
  }

  def start_link(config) do
    register = Keyword.get(config, :register)

    if is_atom(register) do
      GenServer.start_link(__MODULE__, config, name: register)
    else
      GenServer.start_link(__MODULE__, config)
    end
  end

  @impl true
  def init(config) do
    adapter_impl(config).init(config)
  end

  @impl true
  def handle_info({:epgsql, _pid, {:x_log_data, _start_lsn, _end_lsn, binary_msg}}, state) do
    decoded = PgoutputDecoder.decode_message(binary_msg)
    Logger.debug("Received binary message: #{inspect(binary_msg, limit: :infinity)}")
    Logger.debug("Decoded message: " <> inspect(decoded, limit: :infinity))

    {:noreply, process_message(decoded, state)}
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end

  # TODO: Extract subscription logic into common module for other adapters

  @impl true
  def handle_call({:subscribe, receiver_pid}, _from, state) when is_pid(receiver_pid) do
    subscribers = [receiver_pid | state.subscribers]

    {:reply, {:ok, subscribers}, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call({:subscribe, receiver_fun}, _from, state) when is_function(receiver_fun) do
    subscribers = [receiver_fun | state.subscribers]

    {:reply, {:ok, subscribers}, %{state | subscribers: subscribers}}
  end

  defp process_message(%Begin{} = msg, state) do
    %{
      state
      | transaction:
          {msg.final_lsn, %Transaction{changes: [], commit_timestamp: msg.commit_timestamp}}
    }
  end

  defp process_message(
         %Commit{lsn: commit_lsn, end_lsn: end_lsn},
         %State{transaction: {current_txn_lsn, txn}} = state
       )
       when commit_lsn == current_txn_lsn do
    notify_subscribers(txn, state.subscribers)
    :ok = adapter_impl(state.config).acknowledge_lsn(state.connection, end_lsn)

    %{state | transaction: nil}
  end

  # TODO: do something more intelligent here
  defp process_message(%Type{}, state), do: state

  defp process_message(%Relation{} = msg, state) do
    %{state | relations: Map.put(state.relations, msg.id, msg)}
  end

  defp process_message(%Insert{} = msg, state) do
    relation = Map.get(state.relations, msg.relation_id)

    data = data_tuple_to_map(relation.columns, msg.tuple_data)

    new_record = %NewRecord{relation: {relation.namespace, relation.name}, record: data}

    {lsn, txn} = state.transaction
    %{state | transaction: {lsn, %{txn | changes: Enum.reverse([new_record | txn.changes])}}}
  end

  defp process_message(%Update{} = msg, state) do
    relation = Map.get(state.relations, msg.relation_id)

    old_data = data_tuple_to_map(relation.columns, msg.old_tuple_data)
    data = data_tuple_to_map(relation.columns, msg.tuple_data)

    updated_record = %UpdatedRecord{
      relation: {relation.namespace, relation.name},
      old_record: old_data,
      record: data
    }

    {lsn, txn} = state.transaction
    %{state | transaction: {lsn, %{txn | changes: Enum.reverse([updated_record | txn.changes])}}}
  end

  defp process_message(%Delete{} = msg, state) do
    relation = Map.get(state.relations, msg.relation_id)

    data =
      data_tuple_to_map(
        relation.columns,
        msg.old_tuple_data || msg.changed_key_tuple_data
      )

    deleted_record = %DeletedRecord{
      relation: {relation.namespace, relation.name},
      old_record: data
    }

    {lsn, txn} = state.transaction
    %{state | transaction: {lsn, %{txn | changes: Enum.reverse([deleted_record | txn.changes])}}}
  end

  defp process_message(%Truncate{} = msg, state) do
    truncated_relations =
      for truncated_relation <- msg.truncated_relations do
        relation = Map.get(state.relations, truncated_relation)

        %TruncatedRelation{
          relation: {relation.namespace, relation.name}
        }
      end

    {lsn, txn} = state.transaction

    %{
      state
      | transaction: {lsn, %{txn | changes: Enum.reverse(truncated_relations ++ txn.changes)}}
    }
  end

  # TODO: Typecast to meaningful Elixir types here later
  defp data_tuple_to_map(_columns, nil), do: %{}

  defp data_tuple_to_map(columns, tuple_data) do
    for {column, index} <- Enum.with_index(columns, 1),
        do: Types.cast(column, :erlang.element(index, tuple_data)),
        into: %{}
  end

  defp notify_subscribers(%Transaction{} = txn, subscribers) do
    Logger.debug(
      "Notifying subscribers: #{inspect(subscribers)} about transaction: #{inspect(txn)}"
    )

    for(sub <- subscribers, is_pid(sub), do: send(sub, txn)) ++
      for sub <- subscribers, is_function(sub), do: sub.(txn)
  end

  defp adapter_impl(config) do
    Keyword.get(config, :postgres_adapter, Cainophile.Adapters.Postgres.EpgsqlImplementation)
  end

  # Client

  def subscribe(pid, receiver_pid) when is_pid(receiver_pid) do
    GenServer.call(pid, {:subscribe, receiver_pid})
  end

  def subscribe(pid, receiver_fun) when is_function(receiver_fun) do
    GenServer.call(pid, {:subscribe, receiver_fun})
  end
end
