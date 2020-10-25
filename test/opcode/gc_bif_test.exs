defmodule TypeTest.Opcode.GcBifTest do

  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true

  @moduletag :opcodes

  alias Type.Inference.Block.Parser
  alias Type.Inference.Vm

  import Type

  describe "when the opcode is the bit_size bif" do
    @bitstring %Type.Bitstring{size: 0, unit: 1}

    @opcode_bitsz {:gc_bif, :bit_size, {:f, 0}, 1, [x: 1], {:x, 0}}
    test "forward propagates returns non_neg_integer" do
      state = Parser.new([@opcode_bitsz], preload: %{1 => @bitstring})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Vm{xreg: %{0 => builtin(:non_neg_integer), 1 => @bitstring}},
        %Vm{xreg: %{1 => @bitstring}}
      ] = history
    end

    test "forward propagates a fixed number if the size is fixed"

    test "backpropagates to require a value in register 1" do
      state = Parser.new([@opcode_bitsz])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Vm{xreg: %{0 => builtin(:non_neg_integer), 1 => @bitstring}},
        %Vm{xreg: %{1 => @bitstring}}
      ] = history
    end

    test "errors if incompatible datatypes are provided"
  end

end
