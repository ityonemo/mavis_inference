defmodule TypeTest.Abstract.OpcodeFrameworkTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  use Type.Inference.Macros

  @moduletag :abstract

  alias Type.Inference.Block.Parser

  import Type

  describe "an unimplemented opcode" do
    opcode :unimplemented, :unimplemented

    test "warns if you try to use it" do
      state = Parser.new([:unimplemented])

      message = "the opcode :unimplemented is not implemented yet."

      assert (capture_io :stderr, fn ->
        Parser.do_forward(state, __MODULE__)
      end) =~ message
    end
  end

  describe "a noop opcode" do
    opcode :noop, :noop

    @zero_int %{0 => builtin(:integer)}

    test "preserves the registers" do
      empty_map = %{}

      state = Parser.new([:noop])
      assert %{histories: [history]} = Parser.do_forward(state, __MODULE__)
      assert [%{x: ^empty_map}, %{x: ^empty_map}] = history

      state2 = Parser.new([:noop], preload: @zero_int)
      assert %{histories: [history]} = Parser.do_forward(state2, __MODULE__)
      assert [%{x: @zero_int}, %{x: @zero_int}] = history
    end

    test "backpropagation across the noop opcode is noop" do
      first_pass = [:noop]
      |> Parser.new(preload: @zero_int)
      |> Parser.do_forward(__MODULE__)

      assert first_pass == Parser.do_backprop(first_pass, __MODULE__)
    end
  end

  describe "a noop forward method" do
    opcode :noop_fwd do
      forward :noop
    end

    test "preserves the registers" do
      empty_map = %{}

      state = Parser.new([:noop_fwd])
      assert %{histories: [history]} = Parser.do_forward(state, __MODULE__)
      assert [%{x: ^empty_map}, %{x: ^empty_map}] = history

      state2 = Parser.new([:noop_fwd], preload: @zero_int)
      assert %{histories: [history]} = Parser.do_forward(state2, __MODULE__)
      assert [%{x: @zero_int}, %{x: @zero_int}] = history
    end
  end

  describe "an unimplemented forward method" do
    opcode :unimp_fwd do
      forward :unimplemented
    end

    test "warns if you try to use it but passes it forth" do
      state = Parser.new([:unimp_fwd])

      message = "the method forward for opcode :unimp_fwd is not implemented"

      assert (capture_io :stderr, fn ->
        Parser.do_forward(state, __MODULE__)
      end) =~ message
    end
  end

  describe "a noop backward method" do
    opcode :noop_bck do
      forward :noop
      backprop :noop
    end

    test "preserves the registers" do
      first_pass = [:noop_bck]
      |> Parser.new(preload: @zero_int)
      |> Parser.do_forward(__MODULE__)

      assert first_pass == Parser.do_backprop(first_pass, __MODULE__)
    end
  end

  describe "an unimplemented backprop method" do
    opcode :unimp_bck do
      forward :noop
      backprop :unimplemented
    end

    test "warns if you try to use it in the backprop direction" do
      message = "the method backprop for opcode :unimp_bck is not implemented."

      assert (capture_io :stderr, fn ->
        [:unimp_bck]
        |> Parser.new()
        |> Parser.do_forward(__MODULE__)
        |> Parser.do_backprop(__MODULE__)
      end) =~ message
    end
  end

  describe "an opcode with a match in the state" do
    opcode {:matched, match} do
      forward(state = %{x: %{0 => match}}, _meta, ...) do
        {:ok, put_reg(state, {:x,0}, :baz)}
      end
      forward(state, _meta, ...) do
        {:ok, put_reg(state, {:x,0}, :quux)}
      end
    end

    test "is able to match with values in the opcodes" do
      %{histories: [[last | _]]} = [{:matched, :foo}]
      |> Parser.new(preload: %{0 => :foo})
      |> Parser.do_forward(__MODULE__)

      assert last.x[0] == :baz
    end

    test "will pass through values that don't match" do
      %{histories: [[last | _]]} = [{:matched, :foo}]
      |> Parser.new(preload: %{0 => :bar})
      |> Parser.do_forward(__MODULE__)

      assert last.x[0] == :quux
    end
  end

  describe "an opcode with a match in the metadata" do
    opcode {:meta_matched, match} do
      forward(state, %{foo: match}, ...) do
        {:ok, put_reg(state, {:x, 0}, :baz)}
      end
      forward(state, _meta, ...) do
        {:ok, put_reg(state, {:x, 0}, :quux)}
      end
    end

    test "is able to match with metadata values" do
      %{histories: [[last | _]]} = [{:meta_matched, :bar}]
      |> Parser.new(foo: :bar)
      |> Parser.do_forward(__MODULE__)

      assert last.x[0] == :baz
    end

    test "will pass through metadata that doesn't match" do
      %{histories: [[last | _]]} = [{:meta_matched, :bar}]
      |> Parser.new(foo: :baz)
      |> Parser.do_forward(__MODULE__)

      assert last.x[0] == :quux
    end
  end

  test "an opcode that freezes"

  test "an opcode that does dual histories"
end
