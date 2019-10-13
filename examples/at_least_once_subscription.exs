defmodule ExampleApp.AtLeastOnceSubscription do
  def child_spec(_opts) do
    cainophile_opts = [
      epgsql: %{
        host: 'localhost',
        username: "foo",
        password: "bar",
        database: "mydb"
      },
      slot: "example",
      publications: ["example_publication"],
      # passing the handler upfront to make sure the subscription is already set up
      # by the time the very first changeset arrives.
      subscribers: [&handle/1]
    ]

    %{
      id: __MODULE__,
      start: {Cainophile.Adapters.Postgres, :start_link, [cainophile_opts]}
    }
  end

  defp handle(change) do
    if :rand.uniform(2) == 1 do
      # If an exception happens in this handler, the LSN is not committed back to PG.
      # The entire process crashes, a supervisor restarts it,
      # and the changeset is processed one more time ("at least once delivery")
      raise "Expected error"
    else
      IO.inspect(change)
    end
  end
end
