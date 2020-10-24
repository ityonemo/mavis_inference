defmodule TypeTest.Opcode.ReturnTest do

  # tests on the return opcode.

  use ExUnit.Case, async: true

  alias Type.Inference.Block.Parser
  alias Type.Inference.Vm

  import Type

  @moduletag :opcodes

  describe "the return opcode" do
    test "forwards the value in register 0" do
      state = %Parser{code: [:return], histories: [[
        %Vm{xreg: %{0 => builtin(:integer)}}
      ]]}

      %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Vm{xreg: %{0 => builtin(:integer)}},
        %Vm{xreg: %{0 => builtin(:integer)}}
      ] = history
    end
    test "backpropagates to require a value in register 0" do
      state = %Parser{code: [:return]}

      %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Vm{xreg: %{0 => builtin(:any)}},
        %Vm{xreg: %{0 => builtin(:any)}}
      ] = history
    end
  end
end
