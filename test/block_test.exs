defmodule TypeTest.BlockTest do
  use ExUnit.Case, async: true

  alias Type.Inference.{Block, Registers}

  import Type

  test "for trivial code, the block parser generates the expected result" do
    assert [blockdesc] = Block.parse([:return])

    assert %Block{
      needs: %{0 => builtin(:any)},
      makes: builtin(:any)
    } = blockdesc
  end

  describe "the Block.eval/2 function" do
    test "can evaluate a one-arity block with one option" do
      block = [%Block{needs: %{0 => builtin(:integer)}, makes: :foo}]
      reg = %Registers{x: %{0 => 10}}

      assert :foo = Block.eval(block, reg)
    end
  end
end
