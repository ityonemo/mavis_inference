defmodule TypeTest.Abstract.OpcodeTest do
  use ExUnit.Case, async: true

  @moduletag :abstract

  use Type.Inference.Opcodes

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers
  import Type

  describe "a splitting opcode" do
    opcode :splitting do

      # checks register 0 and if it's empty, splits it into either
      # integer -> integer
      # atom -> atom
      forward(state, _meta, ...) do
        if state.x == %{} do
          {:backprop, [
            put_reg(state, {:x, 0}, builtin(:integer)),
            put_reg(state, {:x, 0}, builtin(:atom))]}
        else
          {:ok, state}
        end
      end
    end

    test "causes splits" do
      state = Parser.new([:splitting])

      assert %Parser{histories: histories} = Parser.do_forward(state, __MODULE__)

      assert [[%Registers{x: %{0 => builtin(:integer)}},
               %Registers{x: %{0 => builtin(:integer)}}],
              [%Registers{x: %{0 => builtin(:atom)}},
               %Registers{x: %{0 => builtin(:atom)}}]] = histories
    end
  end

  describe "pairs of opcodes" do

    opcode :combiner do
      forward(state, _meta, ...) do
        cond do
          not is_defined(state, {:x, 0}) ->
            {:backprop, [put_reg(state, {:x, 0}, :foo),
                         put_reg(state, {:x, 0}, :bar)]}
          not is_defined(state, {:x, 1}) ->
            {:backprop, [put_reg(state, {:x, 1}, :foo),
                         put_reg(state, {:x, 1}, :bar)]}
          true ->
            {:ok, state}
        end
      end
    end

    test "combiner alone explores the search space." do
      state = Parser.new([:combiner])

      assert %Parser{histories: histories} = Parser.do_forward(state, __MODULE__)

      assert [[%Registers{x: %{0 => :foo, 1 => :foo}},
               %Registers{x: %{0 => :foo, 1 => :foo}}],
              [%Registers{x: %{0 => :foo, 1 => :bar}},
               %Registers{x: %{0 => :foo, 1 => :bar}}],
              [%Registers{x: %{0 => :bar, 1 => :foo}},
               %Registers{x: %{0 => :bar, 1 => :foo}}],
              [%Registers{x: %{0 => :bar, 1 => :bar}},
               %Registers{x: %{0 => :bar, 1 => :bar}}]] = histories
    end

    opcode :filter do
      forward(state, _meta, ...) do
        cond do
          not is_defined(state, {:x, 0}) ->
            {:backprop, [put_reg(state, {:x, 0}, :foo)]}
          true ->
            {:ok, state}
        end
      end

      backprop(state, _meta, ...) do
        if state.x[0] == :foo do
          {:ok, [state]}
        else
          {:ok, []}
        end
      end
    end

    test "filter alone asserts the existence of foo." do
      state = Parser.new([:filter])

      assert %Parser{histories: histories} = Parser.do_forward(state, __MODULE__)

      assert [[%Registers{x: %{0 => :foo}}, %Registers{x: %{0 => :foo}}]] = histories
    end

    test "combining the two" do
      state = Parser.new([:filter, :combiner])

      assert %Parser{histories: histories} = state
      |> Parser.do_forward(__MODULE__)
      |> Parser.do_forward(__MODULE__)

      assert [[%Type.Inference.Registers{x: %{0 => :foo, 1 => :foo}} | _],
             [%Type.Inference.Registers{x: %{0 => :foo, 1 => :bar}} | _]] = histories
    end

  end

end
