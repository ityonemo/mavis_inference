defmodule TypeTest.OpcodeFramework do
  use Type.Inference.Macros

  opcode :unimplemented do
    :unimplemented
  end

end

defmodule TypeTest.Abstract.OpcodeFrameworkTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @moduletag :abstract

  alias Type.Inference.Block.Parser

  describe "an unimplemented opcode" do
    @op_unimp :unimplemented

    test "warns if you try to use it" do
      state = Parser.new([@op_unimp], preload: %{})

      message = "the opcode :unimplemented is not implemented yet."

      assert (capture_io :stderr, fn ->
        Parser.do_forward(state, TypeTest.OpcodeFramework)
      end) =~ message
    end
  end

end
