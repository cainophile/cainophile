# Examples

## At least once delivery

Use case: 
* you want your subscription to receive changes which happened while your app is offline
* if your subscription crashes, you want to re-process the changeset
 
This can be achieved by using `:subscribers` option with a supervised setup:

```elixir
defmodule ExampleApp.Application do
  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {
        Cainophile.Adapters.Postgres,
        epgsql: %{ ... },
        slot: "example", 
        publications: ["example_publication"],
        subscribers: [&ExampleApp.Subscription.handle/1]
      }
    ]

    opts = [strategy: :one_for_one, name: ExampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule ExampleApp.Subscription do
  def handle(_change), do: ...
end
```

Or move `child_spec` to [AtLeastOnceSubscription](./at_least_once_subscription.exs) module for a more concise syntax:

```elixir
defmodule ExampleApp.Application do
  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
       ExampleApp.AtLeastOnceSubscription
    ]

    opts = [strategy: :one_for_one, name: ExampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
```
