defmodule TypeTest.Opcode.MoveTest do
  # various ways that the move opcode can be a thing

  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  describe "when the opcode is a register movement" do
    @opcode_reg {:move, {:x, 0}, {:x, 1}}
    test "forwards the value in the `from` register" do
      state = Parser.new([@opcode_reg], preload: %{0 => builtin(:integer)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([@opcode_reg])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}},
        %Registers{x: %{0 => builtin(:any)}}
      ] = history
    end

    test "backpropagates a previously seen value" do
      propagated = [@opcode_reg]
      |> Parser.new
      |> Parser.do_forward

      [[last | rest]] = propagated.histories

      new_type = %{last | x: %{0 => builtin(:any), 1 => builtin(:integer)}}

      # rewrite the propragated information to contain typed information
      # in the targeted register.
      state = %{propagated | histories: [[new_type | rest]]}

      Parser.do_backprop(state)
    end
  end

  describe "when the source is a register" do
    @opcode_reg {:move, {:x, 0}, {:x, 1}}
    test "forwards the value in the `from` register" do
      state = Parser.new([@opcode_reg], preload: %{0 => builtin(:integer)})

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end

    test "backpropagates to require a value in register 0" do
      state = Parser.new([@opcode_reg])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [
        %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}},
        %Registers{x: %{0 => builtin(:any)}}
      ] = history
    end

    test "backpropagates a previously seen value" do
      propagated = [@opcode_reg]
      |> Parser.new
      |> Parser.do_forward

      [[last | rest]] = propagated.histories

      new_type = %{last | x: %{0 => builtin(:any), 1 => builtin(:integer)}}

      # rewrite the propragated information to contain typed information
      # in the targeted register.
      end_state = %{propagated | histories: [[new_type | rest]]}

      # check to make sure we don't know that it's supposed to be integer yet.
      assert [%Registers{x: %{0 => builtin(:any)}}] = rest

      # check to see do_backprop this rewrites history.
      assert %{histories: [history]} = Parser.do_backprop(end_state)

      assert [
        %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}},
        %Registers{x: %{0 => builtin(:integer)}}
      ] = history
    end
  end

  describe "when the source is a literal integer" do
    @opcode_int {:move, {:integer, 47}, {:x, 1}}
    test "forwards the source value" do
      state = Parser.new([@opcode_int])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [%Registers{x: %{1 => 47}}, %Registers{x: %{}}] = history
    end

    test "backpropagation is ok, if the values match" do
      propagated = [@opcode_int]
      |> Parser.new
      |> Parser.do_forward

      [[last | rest]] = propagated.histories

      new_type = %{last | x: %{1 => builtin(:integer)}}

      # rewrite the propragated information to contain typed information
      # in the targeted register.
      state = %{propagated | histories: [[new_type | rest]]}

      Parser.do_backprop(state)
    end

    test "backpropagation errors if there is a conflict"
  end

  describe "when the source is a literal atom" do

    @opcode_atom {:move, {:atom, :foo}, {:x, 1}}

    test "forwards the source value" do
      state = Parser.new([@opcode_atom])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [%Registers{x: %{1 => :foo}}, %Registers{x: %{}}] = history
    end

    test "backpropagation is ok, if the values match" do
      propagated = [@opcode_atom]
      |> Parser.new
      |> Parser.do_forward

      [[last | rest]] = propagated.histories

      new_type = %{last | x: %{1 => builtin(:atom)}}

      # rewrite the propragated information to contain typed information
      # in the targeted register.
      state = %{propagated | histories: [[new_type | rest]]}

      Parser.do_backprop(state)
    end

    test "backpropagation errors if there is a conflict"
  end

  describe "when the source is a literal string" do

    @opcode_string {:move, {:literal, "foo"}, {:x, 1}}
    @string remote(String.t(3))

    test "forwards the source value" do
      state = Parser.new([@opcode_string])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [%Registers{x: %{1 => @string}}, %Registers{x: %{}}] = history
    end

    test "backpropagation is ok, if the values match" do
      propagated = [@opcode_string]
      |> Parser.new
      |> Parser.do_forward

      [[last | rest]] = propagated.histories

      new_type = %{last | x: %{1 => @string}}

      # rewrite the propragated information to contain typed information
      # in the targeted register.
      state = %{propagated | histories: [[new_type | rest]]}

      Parser.do_backprop(state)
    end

    test "backpropagation errors if there is a conflict"
  end

  describe "when the source is a empty list" do

    # empty list is represented as nil!!
    @opcode_emptylist {:move, nil, {:x, 1}}

    test "forwards the source value" do
      state = Parser.new([@opcode_emptylist])

      assert %Parser{histories: [history]} = Parser.do_forward(state)

      assert [%Registers{x: %{1 => []}}, %Registers{x: %{}}] = history
    end

    test "backpropagation is ok, if the values match" do
      propagated = [@opcode_emptylist]
      |> Parser.new
      |> Parser.do_forward

      [[last | rest]] = propagated.histories

      new_type = %{last | x: %{1 => []}}

      # rewrite the propragated information to contain typed information
      # in the targeted register.
      state = %{propagated | histories: [[new_type | rest]]}

      Parser.do_backprop(state)
    end

    test "backpropagation errors if there is a conflict"
  end

  describe "the swap opcode" do
    @op_swp {:swap, {:x, 0}, {:x, 1}}
    test "swaps the types of the two registers" do
      assert %{x: %{0 => builtin(:atom), 1 => builtin(:integer)}} = [@op_swp]
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:atom)})
      |> Parser.do_forward
      |> history_final
    end

    test "backpropagates to require a value in register 0" do
      state = [@op_swp]
      |> Parser.new(preload: %{1 => builtin(:atom)})
      |> Parser.do_forward

      assert %{0 => builtin(:any), 1 => builtin(:atom)} = history_start(state).x
      assert %{0 => builtin(:atom), 1 => builtin(:any)} = history_final(state).x
    end

    test "backpropagates to require both values" do
      state = [@op_swp]
      |> Parser.new()
      |> Parser.do_forward

      assert %{0 => builtin(:any), 1 => builtin(:any)} = history_start(state).x
      assert %{0 => builtin(:any), 1 => builtin(:any)} = history_final(state).x
    end

    test "backpropagates with a swapping operation"
  end


end
