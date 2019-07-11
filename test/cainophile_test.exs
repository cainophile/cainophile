defmodule CainophileTest do
  use ExUnit.Case
  doctest Cainophile

  test "greets the world" do
    assert Cainophile.hello() == :world
  end
end
