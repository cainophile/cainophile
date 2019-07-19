defmodule Cainophile.Changes do
  defmodule(Transaction, do: defstruct([:changes, :commit_timestamp]))
  defmodule(NewRecord, do: defstruct([:record]))
  defmodule(UpdatedRecord, do: defstruct([:old_record, :record]))
end
