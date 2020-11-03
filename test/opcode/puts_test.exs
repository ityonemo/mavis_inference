defmodule TypeTest.Opcode.PutsTest do

  #tests on the {:test, x...} opcodes

  use ExUnit.Case, async: true
  use Type.Operators
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Module.ParallelParser
  alias Type.Inference.Registers

  describe "put_list with a nil parameter" do
    @op_put_list_nil [{:put_list, {:x, 0}, nil, {:x, 1}}]

    test "forward propagates the head type correctly" do
      state = @op_put_list_nil
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      assert %Registers{x: %{1 =>
        %Type.List{type: builtin(:integer), nonempty: true}}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_put_list_nil
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any)}} = history_start(state)
      assert %Registers{x: %{1 =>
        %Type.List{type: builtin(:any), nonempty: true}}} = history_finish(state)
    end

    test "passes needs through a backpropagation"
  end

  describe "put_list with a register parameter" do
    @op_put_list_nil [{:put_list, {:x, 0}, {:x, 1}, {:x, 1}}]

    test "forwards to stitch together a normal list" do
      state = @op_put_list_nil
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => []})
      |> fast_forward

      assert %Registers{x: %{1 =>
        %Type.List{type: builtin(:integer), nonempty: true}}} = history_finish(state)
    end

    test "forwards to stitch together an improper list" do
      state = @op_put_list_nil
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:integer)})
      |> fast_forward

      assert %Registers{x: %{1 =>
        %Type.List{type: builtin(:integer), nonempty: true, final: builtin(:integer)}}}
        = history_finish(state)
    end

    test "traps list types to make correct lists" do
      state = @op_put_list_nil
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => %Type.List{type: builtin(:float)}})
      |> fast_forward

      assert %Registers{x: %{1 =>
        %Type.List{type: builtin(:number), nonempty: true}}}
        = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the tail register" do
      state = @op_put_list_nil
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state)
      assert %Registers{x: %{1 =>
        %Type.List{type: builtin(:any), nonempty: true, final: builtin(:any)}}} = history_finish(state)
    end

    test "passes needs through a backpropagation"
  end

  describe "put_tuple_2 with a register parameter" do
    @op_put_tup [{:put_tuple2, {:x, 0}, {:list, [atom: :foo, x: 0]}}]

    test "forwards to stitch together a normal list" do
      state = @op_put_tup
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      assert %Registers{x: %{0 =>
        %Type.Tuple{elements: [:foo, builtin(:integer)]}}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the tail register" do
      state = @op_put_tup
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any)}} = history_start(state)
      assert %Registers{x: %{0 =>
        %Type.Tuple{elements: [:foo, builtin(:any)]}}} = history_finish(state)
    end

    test "passes needs through a backpropagation"
  end

end
