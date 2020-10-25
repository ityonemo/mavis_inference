defmodule TypeTest.Abstract.OpcodeFrameworkTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  use Type.Inference.Macros

  @moduletag :abstract

  alias Type.Inference.Block.Parser

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
