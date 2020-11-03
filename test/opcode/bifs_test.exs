defmodule TypeTest.Opcode.BifsTest do

  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  import Type

  describe "when the opcode is the self bif" do

    @op_self {:bif, :self, :nofail, [], {:x, 0}}

    test "forward propagates returns pid" do
      assert %Registers{x: %{0 => builtin(:pid)}} = [@op_self]
      |> Parser.new
      |> Parser.do_forward
      |> history_finish
    end

    test "backpropagates correctly"
  end

  describe "when the opcode is the map_get bif" do

    @op_map_get {:bif, :map_get, {:f, 10}, [x: 0, x: 1], {:x, 0}}
    @map_req %Type.Map{required: %{foo: :bar}}

    test "forward propagates required singleton type" do
      assert %Registers{x: %{0 => :bar}} = [@op_map_get]
      |> Parser.new(preload: %{0 => @map_req, 1 => :foo})
      |> Parser.do_forward
      |> history_finish
    end

    test "backpropagates the expected key types" do
      state = [@op_map_get]
      |> Parser.new(preload: %{0 => @map_req})
      |> Parser.do_forward
      assert %{1 => :foo} = history_start(state).x
      assert %{0 => :bar} = history_finish(state).x
    end

    test "backpropagates a map with reasonable expected key types" do
      state = [@op_map_get]
      |> Parser.new(preload: %{1 => :foo})
      |> Parser.do_forward
      assert %{0 => %Type.Map{optional: %{foo: builtin(:any)}}} = history_start(state).x
      assert %{0 => builtin(:any)} = history_finish(state).x
    end

    test "backpropagates both the map and the key with types" do
      state = [@op_map_get]
      |> Parser.new()
      |> Parser.do_forward

      assert %{0 => %Type.Map{optional: %{builtin(:any) => builtin(:any)}},
               1 => builtin(:any)} = history_start(state).x
      assert %{0 => builtin(:any)} = history_finish(state).x
    end

    test "backpropagates correctly"
  end

  describe "when the opcode is the > bif" do

    @op_gt {:bif, :>, {:f, 10}, [x: 0, x: 1], {:x, 0}}

    test "forward propagates boolean type" do
      assert %{x: %{0 => builtin(:boolean)}} = [@op_gt]
      |> Parser.new(preload: %{0 => builtin(:any), 1 => builtin(:any)})
      |> Parser.do_forward
      |> history_finish
    end

    test "backpropagates any into right hand side" do
      state = [@op_gt]
      |> Parser.new(preload: %{0 => builtin(:any)})
      |> Parser.do_forward
      assert %{1 => builtin(:any)} = history_start(state).x
      assert %{0 => builtin(:boolean)} = history_finish(state).x
    end

    test "backpropagates both sides" do
      state = [@op_gt]
      |> Parser.new()
      |> Parser.do_forward
      assert %{0 => builtin(:any), 1 => builtin(:any)} = history_start(state).x
      assert %{0 => builtin(:boolean)} = history_finish(state).x
    end

    test "backpropagates correctly"
  end
end
