defmodule TypeTest.Opcode.ReturnTest do

  # tests on the return opcode.

  use ExUnit.Case, async: true

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  import Type

  @moduletag :opcodes

  describe "when forward propagating the return opcode" do
    test "forwards the value in register 0" do
      state = Parser.new([:return], preload: %{0 => builtin(:integer)})

      %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([:return])

      %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:any)}},
        %Registers{x: %{0 => builtin(:any)}}
      ] = history
    end
  end
end
