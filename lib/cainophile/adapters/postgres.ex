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

  alias Cainophile.Changes.{Transaction, NewRecord}

  alias PgoutputDecoder.Messages.{
    Begin,
    Commit,
    Origin,
    Relation,
    Relation.Column,
    Insert,
    Update,
    Delete,
    Truncate,
    Type,
    Unsupported
  }

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl true
  def init(config) do
    adapter_impl =
      Keyword.get(config, :postgres_adapter, Cainophile.Adapters.Postgres.EpgsqlImplementation)

    adapter_impl.init(config)
  end

  @impl true
  def handle_info({:epgsql, _pid, {:x_log_data, _start_lsn, _end_lsn, binary_msg}}, state) do
    decoded = PgoutputDecoder.decode_message(binary_msg)
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
         %Commit{lsn: commit_lsn} = msg,
         %State{transaction: {current_txn_lsn, txn}} = state
       )
       when commit_lsn == current_txn_lsn do
    notify_subscribers(txn, state.subscribers)

    %{state | transaction: nil}
  end

  # TODO: do something more intelligent here
  defp process_message(%Type{}, state), do: state

  defp process_message(%Relation{} = msg, state) do
    %{state | relations: Map.put(state.relations, msg.id, msg)}
  end

  defp process_message(%Insert{} = msg, state) do
    relation = Map.get(state.relations, msg.relation_id)

    # TODO: Typecast to meaningful Elixir types here later
    data =
      for {column, index} <- Enum.with_index(relation.columns, 1),
          do: {column.name, :erlang.element(index, msg.tuple_data)},
          into: %{}

    new_record = %NewRecord{record: data}
    {lsn, txn} = state.transaction
    %{state | transaction: {lsn, %{txn | changes: Enum.reverse([new_record | txn.changes])}}}
  end

  defp process_message(_, state), do: state

  defp notify_subscribers(%Transaction{} = txn, subscribers) do
    Logger.debug(
      "Notifying subscribers: #{inspect(subscribers)} about transaction: #{inspect(txn)}"
    )

    for(sub <- subscribers, is_pid(sub), do: send(sub, txn)) ++
      for sub <- subscribers, is_function(sub), do: sub.(txn)
  end

  # Client

  def subscribe(pid, receiver_pid) when is_pid(receiver_pid) do
    GenServer.call(pid, {:subscribe, receiver_pid})
  end

  def subscribe(pid, receiver_fun) when is_function(receiver_fun) do
    GenServer.call(pid, {:subscribe, receiver_fun})
  end
end
