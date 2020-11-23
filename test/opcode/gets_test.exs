defmodule TypeTest.Opcode.GetsTest do

  #tests on the test opcodes

  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  describe "the get_tuple_element opcode" do

    @op_get_tup {:get_tuple_element, {:x, 0}, 0, {:x, 1}}
    @tup %Type.Tuple{elements: [builtin(:integer)]}

    test "gets the tuple element" do
      state = Parser.new([@op_get_tup], preload: %{0 =>
        %Type.Tuple{elements: [builtin(:integer)]}
      })

      assert %Parser{histories: [history]} = Parser.do_forward(state)
      assert [
        %Registers{x: %{0 => @tup, 1 => builtin(:integer)}},
        %Registers{x: %{0 => @tup}}
      ] = history
    end

    test "backpropagates with any_tuple"

    test "fails when the tuple element isn't there"

    test "warns on anytuple"
  end

  @lst %Type.List{nonempty: true}

  describe "the get_list opcode" do
    @op_get_lst {:get_list, {:x, 0}, {:x, 1}, {:x, 2}}

    test "splits into head and tail" do
      assert %{x: %{1 => builtin(:any),
                    2 => %Type.List{type: builtin(:any), nonempty: false}}} = [@op_get_lst]
      |> Parser.new(preload: %{0 => @lst})
      |> Parser.do_forward
      |> history_final
    end

    test "propagates list type correctly" do
      assert %{x: %{1 => builtin(:atom),
                    2 => %Type.List{type: builtin(:atom), nonempty: false}}} = [@op_get_lst]
      |> Parser.new(preload: %{0 => %{@lst | type: builtin(:atom)}})
      |> Parser.do_forward
      |> history_final
    end

    test "propagates final correctly" do
      union_type = Type.union(%Type.List{final: builtin(:atom), nonempty: true}, builtin(:atom))

      assert %{x: %{1 => builtin(:any),
                    2 => ^union_type}} = [@op_get_lst]
      |> Parser.new(preload: %{0 => %{@lst | final: builtin(:atom)}})
      |> Parser.do_forward
      |> history_final
    end

    test "backpropagates with nonempty any list" do
      state = [@op_get_lst]
      |> Parser.new
      |> Parser.do_forward

      # note that register 2 winds up as "builtin(:any)" because the "final" term could be anything.
      assert %{0 => %Type.List{nonempty: true, final: builtin(:any)}} = history_start(state).x
      assert %{1 => builtin(:any), 2 => builtin(:any)} = history_final(state).x
    end

    test "fails when the tuple element isn't there"

    test "warns on anytuple"
  end

  describe "the get_tl opcode" do
    @op_get_tl {:get_tl, {:x, 0}, {:x, 1}}
    @lst %Type.List{nonempty: true}

    test "splits into head and tail" do
      assert %{x: %{1 => %Type.List{type: builtin(:any), nonempty: false}}} = [@op_get_tl]
      |> Parser.new(preload: %{0 => @lst})
      |> Parser.do_forward
      |> history_final
    end

    test "propagates list type correctly" do
      assert %{x: %{1 => %Type.List{type: builtin(:atom), nonempty: false}}} = [@op_get_tl]
      |> Parser.new(preload: %{0 => %{@lst | type: builtin(:atom)}})
      |> Parser.do_forward
      |> history_final
    end

    test "propagates final correctly" do
      union_type = Type.union(%Type.List{final: builtin(:atom), nonempty: true}, builtin(:atom))

      assert %{x: %{1 => ^union_type}} = [@op_get_tl]
      |> Parser.new(preload: %{0 => %{@lst | final: builtin(:atom)}})
      |> Parser.do_forward
      |> history_final
    end

    test "backpropagates with nonempty any list" do
      state = [@op_get_tl]
      |> Parser.new
      |> Parser.do_forward

      # note that register 2 winds up as "builtin(:any)" because the "final" term could be anything.
      assert %{0 => %Type.List{nonempty: true, final: builtin(:any)}} = history_start(state).x
      assert %{1 => builtin(:any)} = history_final(state).x
    end

    test "fails when the tuple element isn't there"

    test "warns on anytuple"
  end
end
