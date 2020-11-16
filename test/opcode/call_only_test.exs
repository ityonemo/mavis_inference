defmodule TypeTest.Opcode.CallOnlyTest do

  # tests on the return opcode.

  use ExUnit.Case, async: true

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block.Parser
  alias Type.Inference.{Registers, Block}

  import Type

  @moduletag :opcodes

  setup_all do
    BlockCache.preseed({__MODULE__, :fun, 1}, [%Block{
      needs: %{0 => builtin(:integer)},
      makes: builtin(:float)
    }])

    BlockCache.preseed({__MODULE__, :fun, 2}, [%Block{
      needs: %{0 => builtin(:integer), 1 => builtin(:atom)},
      makes: builtin(:float)
    }])

    :ok
  end

  describe "when forward propagating the call_only, 0 opcode" do

    @opcode_0 {:call_only, 0, {__MODULE__, :fun, 1}}

    test "clobbers the value in register 0" do
      state = Parser.new([@opcode_0], preload: %{0 => builtin(:integer)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:float)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end
  end

  describe "when forward propagating the call_only, 1 opcode" do

    @opcode_1 {:call_only, 1, {__MODULE__, :fun, 1}}

    test "forwards the value in register 0" do
      state = Parser.new([@opcode_1], preload: %{0 => builtin(:integer)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:float)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([@opcode_1])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:float)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end
  end

  describe "when forward propagating the call_only, 2 opcode" do

    @opcode_2 {:call_only, 2, {__MODULE__, :fun, 2}}

    test "forwards the value in register 0" do
      state = Parser.new([@opcode_2], preload: %{0 => builtin(:integer), 1 => builtin(:atom)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      # note that history is prepended-to.
      assert [
        %Registers{x: %{0 => builtin(:float)}},
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:atom)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([@opcode_2])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:float)}},
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:atom)}}
      ] = history
    end
  end

end
