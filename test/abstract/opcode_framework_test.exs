defmodule TypeTest.Abstract.OpcodeFrameworkTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  use Type.Inference.Macros

  @moduletag :abstract

  alias Type.Inference.Block.Parser

  describe "an unimplemented opcode" do
    @op_unimp :unimplemented

    opcode :unimplemented do
      :unimplemented
    end

    test "warns if you try to use it" do
      state = Parser.new([@op_unimp], preload: %{})

      message = "the opcode :unimplemented is not implemented yet."

      assert (capture_io :stderr, fn ->
        Parser.do_forward(state, __MODULE__)
      end) =~ message
    end
  end

end
