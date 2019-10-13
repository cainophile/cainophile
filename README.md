# Cainophile

Cainophile is a library to assist you in building Change data capture (CDC) systems in Elixir. With Cainophile, you can quickly and easily stream every change made to your PostgreSQL database, with no plugins, Java, or Zookeeper required. You can read more in the [announcement](https://bbhoss.io/posts/announcing-cainophile/).

## Installation

The package can be installed by adding `cainophile` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cainophile, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/cainophile](https://hexdocs.pm/cainophile).

## PostgreSQL Configuration

Currently, Cainophile only supports PostgreSQL, but other database support may be added later. To get started, you first need to configure PostgreSQL for logical replication:

```sql
ALTER SYSTEM SET wal_level = 'logical';
```

When you change the `wal_level` variable, you'll need to restart your PostgreSQL server. Once you've restarted, go ahead and [create a publication](https://www.postgresql.org/docs/current/sql-createpublication.html) for the tables you want to receive changes for:

```sql
CREATE PUBLICATION example_publication FOR ALL TABLES;
```

### Replica Identity

Cainophile supports all of the settings for [REPLICA IDENTITY](https://www.postgresql.org/docs/current/sql-altertable.html#SQL-CREATETABLE-REPLICA-IDENTITY). I recommend using `FULL` if you can use it, as it will make tracking differences easier as the old data will be sent alongside the new data. Unfortunately, you'll need to set this for each table. 

## Usage
The library is built to be added to your Application's Supervisor tree with a registered name, or simply started and linked to your own GenServer worker that will be responsible for consuming the changes.

Supervisor Usage:

```elixir
defmodule ExampleApp.Application do
  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {
        Cainophile.Adapters.Postgres,
        register: Cainophile.ExamplePublisher, # name this process will be registered globally as, for usage with Cainophile.Adapters.Postgres.subscribe/2
        epgsql: %{ # All epgsql options are supported here
          host: 'localhost',
          username: "username",
          database: "yourdb",
          password: "yourpassword"
        },
        slot: "example", # :temporary is also supported if you don't want Postgres keeping track of what you've acknowledged
        wal_position: {"0", "0"}, # You can provide a different WAL position if desired, or default to allowing Postgres to send you what it thinks you need
        publications: ["example_publication"]
      }
    ]

    opts = [strategy: :one_for_one, name: ExampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Other usage:

```elixir
Cainophile.Adapters.Postgres.start_link(
  register: Cainophile.ExamplePublisher, # name this process will be registered globally as, for usage with Cainophile.Adapters.Postgres.subscribe/2
  epgsql: %{ # All epgsql options are supported here
    host: 'localhost',
    username: "username",
    database: "yourdb",
    password: "yourpassword"
  },
  slot: "example", # :temporary is also supported if you don't want Postgres keeping track of what you've acknowledged
  wal_position: {"0", "0"}, # You can leave this 
  publications: ["example_publication"]
)
```

Then, you can subscribe to changes with `Cainophile.Adapters.Postgres.subscribe/2`:
```elixir
Cainophile.Adapters.Postgres.subscribe(Cainophile.ExamplePublisher, self())
```

This will asyncronously deliver changes as messages to your process. See Cainophile.Changes for what they'll look like.

## At-least-once delivery guarantee

To provide at-least-once delivery guarantee, the subscription needs to be set up **before** the processor starts receiving the changes. This can be achieved via `:subscribers` option. See [examples](./examples) for more details.