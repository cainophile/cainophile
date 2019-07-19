defmodule Cainophile.Adapters.Postgres do
  defmodule(State, do: defstruct([:config, :connection, :subscribers]))
  use GenServer
  require Logger

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
  def handle_info({:epgsql, _pid, {:x_log_data, _, _, binary_msg}}, state) do
    Logger.debug("Received message: " <> inspect(binary_msg, limit: :infinity))

    decoded = PgoutputDecoder.decode_message(binary_msg)
    Logger.debug("Decoded message: " <> inspect(decoded, limit: :infinity))

    {:noreply, state}
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

  # Client

  def subscribe(pid, receiver_pid) when is_pid(receiver_pid) do
    GenServer.call(pid, {:subscribe, receiver_pid})
  end
end
