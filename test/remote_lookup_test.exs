defmodule TypeTest.RemoteLookupTest do
  use ExUnit.Case, async: true

  import Type
  alias Type.List
  alias Type.Inference
  alias Type.Inference.{Block, RemoteLookup}

  describe "remote lookup can find" do
    test "the type of String.split/1" do
      assert {:ok, block} = Inference.fetch_block(String, :split, 1, RemoteLookup)

      assert [%Block{needs: %{0 => remote(String.t())}, makes: %List{type: remote(String.t)}}] = block
    end
  end

  describe "for a compiled file module remote_lookup can find" do
    @example TypeTest.RemoteLookupExamples

    setup do
      Code.ensure_loaded(@example)
      :ok
    end

    test "an unspecced function" do
      assert {:ok, block} = Inference.fetch_block(@example, :no_spec, 1, RemoteLookup)
      assert [%Block{needs: %{0 => builtin(:bitstring)}, makes: builtin(:non_neg_integer)}] = block
    end

    test "a specced function" do
      assert {:ok, block} = Inference.fetch_block(@example, :simple_spec, 1, RemoteLookup)
      assert [%Block{needs: %{0 => builtin(:integer)},
                     makes: builtin(:integer)}] = block
    end

    test "a multi-specced function" do
      assert {:ok, block} = Inference.fetch_block(@example, :multi_spec, 1, RemoteLookup)
      assert [%Block{needs: %{0 => builtin(:atom)}, makes: builtin(:atom)},
              %Block{needs: %{0 => builtin(:integer)}, makes: builtin(:integer)}] = block
    end

    test "rejects a nonexistent function" do

    end
  end

end
