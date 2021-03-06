defmodule TypeTest.Opcode.GcBifsTest do

  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  import Type

  describe "when the opcode is the bit_size bif" do
    @bitstring %Type.Bitstring{size: 0, unit: 1}
    @op_bit_sz {:gc_bif, :bit_size, {:f, 0}, 1, [x: 1], {:x, 0}}

    def bitstring(size), do: %Type.Bitstring{size: size, unit: 0}

    test "forward propagates returns non_neg_integer" do
      state = Parser.new([@op_bit_sz], preload: %{1 => @bitstring})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:non_neg_integer), 1 => @bitstring}},
        %Registers{x: %{1 => @bitstring}}
      ] = history
    end

    test "forward propagates a fixed number if the size is fixed" do
      history = [@op_bit_sz]
      |> Parser.new(preload: %{1 => %Type.Bitstring{size: 8, unit: 0}})
      |> Parser.do_forward

      assert %{0 => 8} = history_final(history).x
    end

    test "forward propagates a multiple numbers if it's not" do
      bs_union = Type.union(for i <- 1..3, do: %Type.Bitstring{size: i})

      history = [@op_bit_sz]
      |> Parser.new(preload: %{1 => bs_union})
      |> Parser.do_forward

      assert %{0 => 1..3} = history_final(history).x

      history = [@op_bit_sz]
      |> Parser.new(preload: %{1 => %Type.Bitstring{size: 8, unit: 8}})
      |> Parser.do_forward

      assert %{0 => builtin(:pos_integer)} = history_final(history).x
    end

    test "triggers a backpropagation if no value in target register" do
      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward

      %{1 => @bitstring} = history_start(history).x
      %{0 => builtin(:non_neg_integer), 1 => @bitstring} = history_final(history).x
    end

    test "errors if incompatible datatypes are provided"

    test "backpropagates correctly if the return type has a single integer" do
      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> change_final(0, 0)
      |> Parser.do_backprop

      assert %{1 => %Type.Bitstring{size: 0, unit: 0}} = history_start(history).x

      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> change_final(0, 16)
      |> Parser.do_backprop

      assert %{1 => %Type.Bitstring{size: 16, unit: 0}} = history_start(history).x
    end

    test "backpropagates correctly with groups of integers" do
      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> Parser.do_backprop

      assert %{1 => %Type.Bitstring{size: 0, unit: 1}} = history_start(history).x

      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> change_final(0, builtin(:pos_integer))
      |> Parser.do_backprop

      assert %{1 => %Type.Bitstring{size: 1, unit: 1}} = history_start(history).x

      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> change_final(0, builtin(:non_neg_integer))
      |> Parser.do_backprop

      assert %{1 => @bitstring} = history_start(history).x


      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> change_final(0, Type.union(0, 8))
      |> Parser.do_backprop

      allowed_bitstrings = Type.union(bitstring(0), bitstring(8))

      assert %{1 => ^allowed_bitstrings} = history_start(history).x

      history = [@op_bit_sz]
      |> Parser.new
      |> Parser.do_forward
      |> change_final(0, 1..4)
      |> Parser.do_backprop

      allowed_bitstrings = Type.union(for i <- 1..4, do: bitstring(i))

      assert %{1 => ^allowed_bitstrings} = history_start(history).x
    end
  end

  describe "when the opcode is the byte_size bif" do
    @binary %Type.Bitstring{size: 0, unit: 8}

    @op_byt_sz {:gc_bif, :byte_size, {:f, 0}, 1, [x: 1], {:x, 0}}

    test "forward propagates returns non_neg_integer" do
      state = Parser.new([@op_byt_sz], preload: %{1 => @binary})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:non_neg_integer), 1 => @binary}},
        %Registers{x: %{1 => @binary}}
      ] = history
    end

    test "forward propagates a fixed number if the size is fixed"

    test "backpropagates to require a value in register 1" do
      state = Parser.new([@op_byt_sz])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:non_neg_integer), 1 => @binary}},
        %Registers{x: %{1 => @binary}}
      ] = history
    end

    test "errors if incompatible datatypes are provided"
  end

  describe "length bif" do
    @op_len {:gc_bif, :length, {:f, 0}, 2, [x: 1], {:x, 0}}

    test "forward propagates returns zero for empty list" do
      assert %{x: %{0 => 0}} = [@op_len]
      |> Parser.new(preload: %{1 => []})
      |> Parser.do_forward
      |> history_final
    end

    test "forward propagates arbitrary list returns non_neg_integer" do
      assert %{x: %{0 => builtin(:non_neg_integer)}} = [@op_len]
      |> Parser.new(preload: %{1 => %Type.List{}})
      |> Parser.do_forward
      |> history_final
    end

    test "forward propagates nonempty list returns non_neg_integer" do
      assert %{x: %{0 => builtin(:pos_integer)}} = [@op_len]
      |> Parser.new(preload: %{1 => %Type.List{nonempty: true}})
      |> Parser.do_forward
      |> history_final
    end

    test "backpropagates to require a value in register 1" do
      state = [@op_len]
      |> Parser.new
      |> Parser.do_forward

      assert %{1 => %Type.List{}} = history_start(state).x
      assert %{0 => builtin(:non_neg_integer)} = history_final(state).x
    end

    test "overbroad finals"

    test "errors if incompatible datatypes are provided"
  end

  describe "when the opcode is the map_size bif" do
    @any_map %Type.Map{optional: %{builtin(:any) => builtin(:any)}}
    @op_map_sz {:gc_bif, :map_size, {:f, 0}, 1, [x: 1], {:x, 0}}

    test "forward propagates returns non_neg_integer" do
      assert %{x: %{0 => builtin(:non_neg_integer)}} = [@op_map_sz]
      |> Parser.new(preload: %{1 => @any_map})
      |> Parser.do_forward
      |> history_final
    end

    test "forward propagates a fixed number if there are only required keys"

    test "backpropagates to require a value in register 1" do
      state = [@op_map_sz]
      |> Parser.new()
      |> Parser.do_forward

      assert %{1 => @any_map} = history_start(state).x
      assert %{0 => builtin(:non_neg_integer)} = history_final(state).x
    end

    test "errors if incompatible datatypes are provided"
  end

  @add_result %{
    {builtin(:pos_integer), builtin(:pos_integer)} => builtin(:pos_integer),
    {builtin(:pos_integer), 0}                     => builtin(:pos_integer),
    {builtin(:pos_integer), builtin(:neg_integer)} => builtin(:integer),
    {0,                     builtin(:pos_integer)} => builtin(:pos_integer),
    {0,                     0}                     => 0,
    {0,                     builtin(:neg_integer)} => builtin(:neg_integer),
    {builtin(:neg_integer), builtin(:pos_integer)} => builtin(:integer),
    {builtin(:neg_integer), 0}                     => builtin(:neg_integer),
    {builtin(:neg_integer), builtin(:neg_integer)} => builtin(:neg_integer),
    {builtin(:pos_integer), builtin(:float)}       => builtin(:float),
    {builtin(:float),       builtin(:pos_integer)} => builtin(:float),
    {builtin(:float),       builtin(:float)}       => builtin(:float)}

  describe "when the opcode is the addition bif" do
    @opcode_add {:gc_bif, :+, {:f, 0}, 2, [x: 0, x: 1], {:x, 0}}

    test "triggers a full backpropagation on all number choices" do
      state = Parser.new([@opcode_add])

      assert %Parser{histories: histories} = Parser.do_forward(state)

      Enum.each(@add_result, fn {{left, right}, res} ->
        assert [
          %Registers{x: %{0 => res, 1 => right}},
          %Registers{x: %{0 => left, 1 => right}}] in histories
      end)
    end
  end

  @sub_result %{
    {builtin(:pos_integer), builtin(:pos_integer)} => builtin(:integer),
    {builtin(:pos_integer), 0}                     => builtin(:pos_integer),
    {builtin(:pos_integer), builtin(:neg_integer)} => builtin(:pos_integer),
    {0,                     builtin(:pos_integer)} => builtin(:neg_integer),
    {0,                     0}                     => 0,
    {0,                     builtin(:neg_integer)} => builtin(:pos_integer),
    {builtin(:neg_integer), builtin(:pos_integer)} => builtin(:neg_integer),
    {builtin(:neg_integer), 0}                     => builtin(:neg_integer),
    {builtin(:neg_integer), builtin(:neg_integer)} => builtin(:integer),
    {builtin(:pos_integer), builtin(:float)}       => builtin(:float),
    {builtin(:float),       builtin(:pos_integer)} => builtin(:float),
    {builtin(:float),       builtin(:float)}       => builtin(:float)}

  describe "when the opcode is the subtraction bif" do
    @opcode_sub {:gc_bif, :-, {:f, 0}, 2, [x: 0, x: 1], {:x, 0}}

    test "triggers a full backpropagation on all number choices" do
      state = Parser.new([@opcode_sub])

      assert %Parser{histories: histories} = Parser.do_forward(state)

      Enum.each(@sub_result, fn {{left, right}, res} ->
        assert [
          %Registers{x: %{0 => res, 1 => right}},
          %Registers{x: %{0 => left, 1 => right}}] in histories
      end)
    end
  end

  @mul_result %{
    {builtin(:pos_integer), builtin(:pos_integer)} => builtin(:pos_integer),
    {builtin(:pos_integer), 0}                     => 0,
    {builtin(:pos_integer), builtin(:neg_integer)} => builtin(:neg_integer),
    {0,                     builtin(:pos_integer)} => 0,
    {0,                     0}                     => 0,
    {0,                     builtin(:neg_integer)} => 0,
    {builtin(:neg_integer), builtin(:pos_integer)} => builtin(:neg_integer),
    {builtin(:neg_integer), 0}                     => 0,
    {builtin(:neg_integer), builtin(:neg_integer)} => builtin(:pos_integer),
    {builtin(:pos_integer), builtin(:float)}       => builtin(:float),
    {builtin(:float),       builtin(:pos_integer)} => builtin(:float),
    {builtin(:float),       builtin(:float)}       => builtin(:float)}

  describe "when the opcode is the multiplication bif" do
    @opcode_mul {:gc_bif, :*, {:f, 0}, 2, [x: 0, x: 1], {:x, 0}}

    test "triggers a full backpropagation on all number choices" do
      state = Parser.new([@opcode_mul])

      assert %Parser{histories: histories} = Parser.do_forward(state)

      Enum.each(@mul_result, fn {{left, right}, res} ->
        assert [
          %Registers{x: %{0 => res, 1 => right}},
          %Registers{x: %{0 => left, 1 => right}}] in histories
      end)
    end
  end

  describe "chained bif test" do
    @opcode_bitsz2 {:gc_bif, :bit_size, {:f, 0}, 1, [x: 1], {:x, 1}}
    test "a lambda with chained code" do
      state = [@opcode_bitsz2, @opcode_add]
      |> Parser.new
      |> fast_forward

      # there is a pos integer, bitstring -> pos_integer story.
      assert Enum.any?(state.histories, &match?(
        [%{x: %{0 => builtin(:pos_integer)}}, _,
         %{x: %{0 => builtin(:pos_integer), 1 => builtin(:bitstring)}}], &1))

      # and a 0 -> non_neg_integer story.
      assert Enum.any?(state.histories, &match?(
        [%{x: %{0 => builtin(:non_neg_integer)}}, _,
         %{x: %{0 => 0, 1 => builtin(:bitstring)}}], &1))
    end
  end
end
