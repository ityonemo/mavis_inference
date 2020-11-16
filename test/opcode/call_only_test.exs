defmodule TypeTest.Opcode.CallOnlyTest do

  # tests on the return opcode.

  use ExUnit.Case, async: true

  alias Type.Inference.Block.Parser
  alias Type.Inference.{Registers, Block}

  import Type

  @moduletag :opcodes

  describe "when forward propagating the call_only, 0 opcode" do

    @opcode_0 {:call_only, 0, {__MODULE__, :fun, 1}}

    setup do
      # preseed the test thread with a message containing the block
      # spec for the function that it is going to look up!
      #ParallelParser.send_lookup(self(), nil, :fun, 1, [%Block{
      #  needs: %{},
      #  makes: builtin(:float)
      #}])
    end

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

    setup do
      # preseed the test thread with a message containing the block
      # spec for the function that it is going to look up!
      #ParallelParser.send_lookup(self(), nil, :fun, 1, [%Block{
      #  needs: %{0 => builtin(:integer)},
      #  makes: builtin(:integer)
      #}])
    end

    test "forwards the value in register 0" do
      state = Parser.new([@opcode_1], preload: %{0 => builtin(:integer)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([@opcode_1])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end
  end

  describe "when forward propagating the call_only, 2 opcode" do

    @opcode_2 {:call_only, 2, {__MODULE__, :fun, 2}}

    setup do
      # preseed the test thread with a message containing the block
      # spec for the function that it is going to look up!
      #ParallelParser.send_lookup(self(), nil, :fun, 2, [%Block{
      #  needs: %{0 => builtin(:integer), 1 => builtin(:integer)},
      #  makes: builtin(:float)
      #}])
    end

    test "forwards the value in register 0" do
      state = Parser.new([@opcode_2], preload: %{0 => builtin(:integer), 1 => builtin(:integer)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      # note that history is prepended-to.
      assert [
        %Registers{x: %{0 => builtin(:float), 1 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([@opcode_2])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:float), 1 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}}
      ] = history
    end
  end

end
