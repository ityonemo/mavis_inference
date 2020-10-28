defmodule TypeTest.Opcode.GcBifTest do

  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true

  @moduletag :opcodes

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  import Type

  describe "when the opcode is the bit_size bif" do
    @bitstring %Type.Bitstring{size: 0, unit: 1}

    @opcode_bitsz {:gc_bif, :bit_size, {:f, 0}, 1, [x: 1], {:x, 0}}

    test "forward propagates returns non_neg_integer" do
      state = Parser.new([@opcode_bitsz], preload: %{1 => @bitstring})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:non_neg_integer), 1 => @bitstring}},
        %Registers{x: %{1 => @bitstring}}
      ] = history
    end

    test "forward propagates a fixed number if the size is fixed"

    test "backpropagates to require a value in register 1" do
      state = Parser.new([@opcode_bitsz])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:non_neg_integer), 1 => @bitstring}},
        %Registers{x: %{1 => @bitstring}}
      ] = history
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
    {builtin(:integer),     builtin(:float)}       => builtin(:float),
    {builtin(:float),       builtin(:integer)}     => builtin(:float),
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

  describe "chained bif test" do
    @opcode_bitsz2 {:gc_bif, :bit_size, {:f, 0}, 1, [x: 1], {:x, 1}}
    test "a lambda with chained code" do
      state = [@opcode_bitsz2, @opcode_add]
      |> Parser.new
      |> Parser.do_forward
      |> Parser.do_forward

      assert %{histories: [
        [%{x: %{0 => builtin(:pos_integer)}}, _,
         %{x: %{0 => builtin(:pos_integer), 1 => builtin(:bitstring)}}] | _
      ]} = state
    end
  end
end
