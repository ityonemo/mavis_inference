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

    test "defined answers for separable types"

    test "backpropagates correctly"
  end

  describe "when the opcode is the :=/= bif" do

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

    test "defined answers for separable types"

    test "backpropagates correctly"
  end

  describe "when the opcode is the node bif" do

    @op_node {:bif, :node, :nofail, [], {:x, 0}}

    test "forward propagates node type" do
      assert %{x: %{0 => builtin(:node)}} = [@op_node]
      |> Parser.new
      |> Parser.do_forward
      |> history_finish
    end

    test "backpropagates correctly"
  end

  describe "bif element" do

    @op_element {:bif, :element, {:f, 0}, [x: 1, x: 0], {:x, 3}}

    test "forward propagates the element type" do
      assert %{x: %{3 => builtin(:integer)}} = [@op_element]
      |> Parser.new(preload: %{0 => 1, 1 => %Type.Tuple{elements: [:ok, builtin(:integer)]}})
      |> Parser.do_forward
      |> history_finish
    end

    test "triggers a backpropagation on absent tuple" do
      state = [@op_element]
      |> Parser.new(preload: %{0 => 1})
      |> Parser.do_forward

      # TODO: consider changing this if we can have a tuple type with a minimum size
      assert %{1 => %Type.Tuple{elements: {:min, 0}}} = history_start(state).x
      assert %{3 => builtin(:any)} = history_finish(state).x
    end

    test "triggers a backpropagation on absent index" do
      state = [@op_element]
      |> Parser.new(preload: %{1 => %Type.Tuple{elements: [:ok, builtin(:integer)]}})

      |> Parser.do_forward

      union_type = Type.union(:ok, builtin(:integer))

      assert %{0 => 0..1} = history_finish(state).x
      assert %{3 => ^union_type} = history_finish(state).x
    end

    test "triggers a backpropagation on absent both" do
      state = [@op_element]
      |> Parser.new
      |> Parser.do_forward

      assert %{0 => builtin(:non_neg_integer), 1 => %Type.Tuple{elements: {:min, 0}}} = history_finish(state).x
      assert %{3 => builtin(:any)} = history_finish(state).x
    end

    test "backpropagates correctly"
  end

  describe "bif tuple_size" do
    @op_tup_sz {:bif, :tuple_size, {:f, 0}, [x: 0], {:x, 3}}

    test "forward propagates the tuple size on a fixed size tuple" do
      assert %{x: %{3 => 2}} = [@op_tup_sz]
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: [:ok, builtin(:integer)]}})
      |> Parser.do_forward
      |> history_finish
    end

    test "forward propagates the tuple size on an any tuple" do
      assert %{x: %{3 => builtin(:non_neg_integer)}} = [@op_tup_sz]
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: {:min, 0}}})
      |> Parser.do_forward
      |> history_finish
    end

    test "triggers a backpropagation on absent tuple" do
      state = [@op_tup_sz]
      |> Parser.new()
      |> Parser.do_forward

      # TODO: consider changing this if we can have a tuple type with a minimum size
      assert %{0 => %Type.Tuple{elements: {:min, 0}}} = history_start(state).x
      assert %{3 => builtin(:non_neg_integer)} = history_finish(state).x
    end

    test "errorneous types"

    test "backpropagates correctly"
  end

  test "bif node/0"
  test "bif node/1"
end
