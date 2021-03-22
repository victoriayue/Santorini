defmodule SantoriniTest do
  use ExUnit.Case
  doctest Santorini.CLI


  test "read json" do

    Santorini.CLI.main()

  end
end
