defmodule Cainophile.Changes do
  defmodule(Transaction, do: defstruct([:changes, :commit_timestamp]))
  defmodule(NewRecord, do: defstruct([:record]))
end
