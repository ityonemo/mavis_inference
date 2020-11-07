defmodule TypeTest.Abstract.OpcodeTest do
  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  @moduletag :abstract

  use Type.Inference.Opcodes

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  @x0 {:x, 0}
  @x1 {:x, 1}

  describe "an opcode that splits on backpropgation" do
    opcode :split_back do
      # checks register 0 and if it's empty, splits it into either
      # integer -> integer
      # atom -> atom

      forward(regs, _meta, ...) when not is_defined(regs, @x0) do
        {:backprop, [
          put_reg(regs, @x0, builtin(:integer)),
          put_reg(regs, @x0, builtin(:atom))]}
      end
      forward :noop
    end

    test "creates multiple histories" do
      result = [:split_back]
      |> Parser.new
      |> Parser.do_forward(__MODULE__)

      assert %{0 => builtin(:integer)} = history_start(result, 0).x
      assert %{0 => builtin(:atom)} = history_start(result, 1).x
    end
  end

  describe "an opcode that filters on input" do
    opcode :filter do
      forward(regs, _meta, ...) when not is_defined(regs, @x0) do
        {:backprop, [put_reg(regs, @x0, :foo)]}
      end

      forward :noop

      backprop(regs, _meta, ...) when is_reg(regs, @x0, :foo) do
        :noop
      end

      backprop(regs, _meta, ...) do
        :no_return
      end
    end

    test "can clear " do
      state = Parser.new([:filter])

      assert %Parser{histories: histories} = Parser.do_forward(state, __MODULE__)

      assert [[%Registers{x: %{0 => :foo}}, %Registers{x: %{0 => :foo}}]] = histories
    end
  end

  describe "an opcode that splits on backpropagation for multiple registers" do
    opcode :multi_split_back do
      forward(regs, _meta, ...) when not is_defined(regs, @x0) do
        {:backprop, [put_reg(regs, @x0, :foo), put_reg(regs, @x0, :bar)]}
      end

      forward(regs, _meta, ...) when not is_defined(regs, @x1) do
        {:backprop, [put_reg(regs, @x1, :foo), put_reg(regs, @x1, :bar)]}
      end

      forward :noop
    end

    test "explores the search space." do
      result = [:multi_split_back]
      |> Parser.new
      |> Parser.do_forward(__MODULE__)

      assert %{0 => :foo, 1 => :foo} = history_start(result, 0).x
      assert %{0 => :foo, 1 => :bar} = history_start(result, 1).x
      assert %{0 => :bar, 1 => :foo} = history_start(result, 2).x
      assert %{0 => :bar, 1 => :bar} = history_start(result, 3).x
    end

    test "can be combined with a filter" do
      result = [:filter, :multi_split_back]
      |> Parser.new()
      |> fast_forward(__MODULE__)

      assert %{0 => :foo, 1 => :foo} = history_finish(result, 0).x
      assert %{0 => :foo, 1 => :bar} = history_finish(result, 1).x

      assert 2 == length(result.histories)
    end
  end

  test "an opcode that freezes"

  test "an opcode that does dual histories"

end
