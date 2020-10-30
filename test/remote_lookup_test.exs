defmodule TypeTest.RemoteLookupTest do
  use ExUnit.Case, async: true

  import Type
  alias Type.List
  alias Type.Inference.{Block, RemoteLookup}

  describe "remote lookup can find" do
    test "the type of String.split/1" do
      assert {:ok, block} = RemoteLookup.infer(String, :split, 1)

      assert [%Block{needs: %{0 => remote(String.t())}, makes: %List{type: remote(String.t)}}] = block
    end
  end

end
