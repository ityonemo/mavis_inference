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
      assert [%{xreg: ^empty_map}, %{xreg: ^empty_map}] = history

      state2 = Parser.new([:noop], preload: @zero_int)
      assert %{histories: [history]} = Parser.do_forward(state2, __MODULE__)
      assert [%{xreg: @zero_int}, %{xreg: @zero_int}] = history
    end

    test "backpropagation across the noop opcode is noop" do

      first_pass = [:noop]
      |> Parser.new(preload: @zero_int)
      |> Parser.do_forward(__MODULE__)

      assert first_pass == Parser.do_backprop(first_pass, __MODULE__)
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

end
