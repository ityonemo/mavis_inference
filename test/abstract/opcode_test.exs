defmodule TypeTest.Abstract.OpcodeTest do
  use ExUnit.Case, async: true

  @moduletag :abstract

  use Type.Inference.Macros

  alias Type.Inference.Block.Parser
  alias Type.Inference.Vm
  import Type

  describe "a splitting opcode" do
    @op_split :splitting

    opcode :splitting do

      # checks register 0 and if it's empty, splits it into either
      # integer -> integer
      # atom -> atom
      forward(state, ...) do
        if state.xreg == %{} do
          {:backprop, [
            put_reg(state, 0, builtin(:integer)),
            put_reg(state, 0, builtin(:atom))]}
        else
          {:ok, state}
        end
      end
    end

    test "causes splits" do
      state = Parser.new([@op_split], preload: %{})

      assert %Parser{histories: histories} = Parser.do_forward(state, __MODULE__)

      assert [[%Vm{xreg: %{0 => builtin(:integer)}},
               %Vm{xreg: %{0 => builtin(:integer)}}],
              [%Vm{xreg: %{0 => builtin(:atom)}},
               %Vm{xreg: %{0 => builtin(:atom)}}]] = histories
    end
  end

end
