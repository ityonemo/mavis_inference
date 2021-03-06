defmodule TypeTest.Opcode.SelectValTest do
  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  describe "when the opcode is a register movement" do
    @op_list [atom: :foo, f: 4, atom: :bar, f: 5]

    @opcode_sel {:select_val, {:x, 0}, {:f, 0}, {:list, @op_list}}

    setup do
      BlockCache.preseed({__MODULE__, 4}, [%Block{
        needs: %{},
        makes: builtin(:integer)
      }])
      BlockCache.preseed({__MODULE__, 5}, [%Block{
        needs: %{},
        makes: builtin(:float)
       }])
    end

    test "forwards the value in the `from` register" do
      state = Parser.new([@opcode_sel], preload: %{0 => :foo}, module: __MODULE__)
      assert %Parser{histories: [history]} = Parser.do_forward(state)
      assert [
        %Registers{x: %{0 => builtin(:integer)}},
        %Registers{x: %{0 => :foo}}
      ] = history

      state = Parser.new([@opcode_sel], preload: %{0 => :bar}, module: __MODULE__)
      assert %Parser{histories: [history]} = Parser.do_forward(state)
      assert [
        %Registers{x: %{0 => builtin(:float)}},
        %Registers{x: %{0 => :bar}}
      ] = history
    end

    test "backpropagates if the registers are not known" do
      state = Parser.new([@opcode_sel], module: __MODULE__)
      assert %Parser{histories: histories} = Parser.do_forward(state)
      assert [
        [%Registers{x: %{0 => builtin(:float)}}, %Registers{x: %{0 => :bar}}],
        [%Registers{x: %{0 => builtin(:integer)}}, %Registers{x: %{0 => :foo}}]
      ] = histories
    end
  end

end
