defmodule TypeTest.Opcode.ApplyTest do

  # tests on the return opcode.

  use ExUnit.Case, async: true
  
  alias Type.Inference.Block.Parser
  alias Type.Inference.{Registers, Block}

  import Type

  @moduletag :opcodes

  describe "the apply 0 opcode" do

    @op_apply {:apply, 0}

    test "research the apply opcode"
  end

end
