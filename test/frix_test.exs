defmodule FrixTest do
  use ExUnit.Case
  doctest Frix

  test "greets the world" do
    assert Frix.hello() == :world
  end
end
