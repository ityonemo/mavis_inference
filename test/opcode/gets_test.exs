defmodule TypeTest.Opcode.GetsTest do

  #tests on the test opcodes

  use ExUnit.Case, async: true

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Module.ParallelParser
  alias Type.Inference.Registers

  describe "the get_tuple_element opcode" do

    @op_get_tup {:get_tuple_element, {:x, 0}, 0, {:x, 1}}
    @tup %Type.Tuple{elements: [builtin(:integer)]}

    test "gets the tuple element" do
      state = Parser.new([@op_get_tup], preload: %{0 =>
        %Type.Tuple{elements: [builtin(:integer)]}
      })

      assert %Parser{histories: [history]} = Parser.do_forward(state)
      assert [
        %Registers{x: %{0 => @tup, 1 => builtin(:integer)}},
        %Registers{x: %{0 => @tup}}
      ] = history
    end

    test "backpropagates with any_tuple"

    test "fails when the tuple element isn't there"

    test "warns on anytuple"
  end
end
