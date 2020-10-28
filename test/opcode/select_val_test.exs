defmodule TypeTest.Opcode.SelectValTest do
  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Module.ParallelParser
  alias Type.Inference.Vm

  describe "when the opcode is a register movement" do
    @op_list [atom: :foo, f: 4, atom: :bar, f: 5]

    @opcode_sel {:select_val, {:x, 0}, {:f, 0}, {:list, @op_list}}

    setup do
      # preseed the test thread with a message containing the block
      # spec for the function that it is going to look up!
      ParallelParser.send_lookup(self(), 4, :fun, 0, [%Block{
        needs: %{},
        makes: builtin(:integer)
      }])

      ParallelParser.send_lookup(self(), 5, :fun, 0, [%Block{
        needs: %{},
        makes: builtin(:float)
      }])
    end

    test "forwards the value in the `from` register" do
      state = Parser.new([@opcode_sel], preload: %{0 => :foo})
      assert %Parser{histories: [history]} = Parser.do_forward(state)
      assert [
        %Vm{xreg: %{0 => builtin(:integer)}},
        %Vm{xreg: %{0 => :foo}}
      ] = history

      state = Parser.new([@opcode_sel], preload: %{0 => :bar})
      assert %Parser{histories: [history]} = Parser.do_forward(state)
      assert [
        %Vm{xreg: %{0 => builtin(:float)}},
        %Vm{xreg: %{0 => :bar}}
      ] = history
    end

    test "backpropagates if the registers are not known" do
      state = Parser.new([@opcode_sel])
      assert %Parser{histories: histories} = Parser.do_forward(state)
      assert [
        [%Vm{xreg: %{0 => builtin(:float)}}, %Vm{xreg: %{0 => :bar}}],
        [%Vm{xreg: %{0 => builtin(:integer)}}, %Vm{xreg: %{0 => :foo}}]
      ] = histories
    end
  end

end
