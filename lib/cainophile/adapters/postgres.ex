defmodule Cainophile.Adapters.Postgres do
  defmodule(State, do: defstruct([:config, :epgsql]))
  use GenServer

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl true
  def init(config) do
    epgsql_config =
      Keyword.get(config, :epgsql, %{})
      |> Map.put(:replication, "database")

    {xlog, offset} = Keyword.get(config, :wal_position, {"0", "0"})

    publication_names =
      Keyword.get(config, :publications)
      |> Enum.map(fn pub -> ~s("#{pub}") end)
      |> Enum.join(",")

    case :epgsql.connect(epgsql_config) do
      {:ok, epgsql_pid} ->
        {:ok, slot_name} =
          create_replication_slot(epgsql_pid, Keyword.get(config, :slot, :temporary))

        :ok =
          :epgsql.start_replication(
            epgsql_pid,
            slot_name,
            self(),
            [],
            '#{xlog}/#{offset}',
            'proto_version \'1\', publication_names \'#{publication_names}\''
          )

        {:ok, %State{config: config, epgsql: epgsql_pid}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end

  defp create_replication_slot(epgsql_pid, slot) do
    {slot_name, start_replication_command} =
      case slot do
        name when is_binary(name) ->
          # TODO
          {name, "SELECT 1;"}

        :temporary ->
          slot_name = self_as_slot_name()

          {slot_name,
           "CREATE_REPLICATION_SLOT #{slot_name} TEMPORARY LOGICAL pgoutput NOEXPORT_SNAPSHOT"}
      end

    case :epgsql.squery(epgsql_pid, start_replication_command) do
      {:ok, _, _} ->
        {:ok, slot_name}

      {:error, epgsql_error} ->
        {:error, epgsql_error}
    end
  end

  # TODO: Replace with better slot name generator
  defp self_as_slot_name() do
    "#PID<" <> pid = inspect(self())

    pid_number =
      String.replace(pid, ".", "_")
      |> String.slice(0..-2)

    "pid" <> pid_number
  end
end
