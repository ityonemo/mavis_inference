defmodule TypeTest.BlockParserTest do
  use ExUnit.Case, async: true

  alias Type.Inference.{Block, Vm}

  import Type

  test "for trivial code, the block parser generates the expected result" do
    assert [blockdesc] = Block.parse([:return], __MODULE__)

    assert %Block{
      needs: %{0 => builtin(:any)},
      makes: builtin(:any)
    } = blockdesc
  end
end
