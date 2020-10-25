defmodule TypeTest.AbstractOpcodes do
  use Type.Inference.Macros

  opcode :splitting do
    :unimplemented
  end

end

defmodule TypeTest.Abstract.OpcodeTest do
  use ExUnit.Case, async: true

  @moduletag :abstract

  alias Type.Inference.Block.Parser
  alias Type.Inference.Vm
  import Type

  describe "a splitting opcode" do
    @op_split :splitting

    test "causes splits" do
      state = Parser.new([@op_split], preload: %{})

      assert %Parser{histories: [history]} = Parser.do_forward(state, TypeTest.AbstractOpcodes)

      assert [
        %Vm{xreg: %{0 => builtin(:integer), 1 => builtin(:integer)}},
        %Vm{xreg: %{0 => builtin(:integer)}}
      ] = history
    end
  end

end
