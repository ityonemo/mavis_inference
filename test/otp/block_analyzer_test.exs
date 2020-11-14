defmodule TypeTest.Inference.OTP.BlockAnalyzerTest do
  use ExUnit.Case, async: true

  @moduletag :otp

  import Type, only: :macros
  import Mox

  alias Type.Inference.Application.{BlockCache, BlockAnalyzer}
  alias __MODULE__.BlockInference.Stub
  alias Type.Inference.Block

  setup_all do
    defmock(Stub, for: Type.Inference.Block.Parser.Api)
    :ok
  end

  setup :verify_on_exit!

  @default_block [%Block{needs: %{}, makes: builtin(:any)}]

  describe "when the analyzer is passed an export" do
    test "the result is retrievable from the block cache by mfa" do
      expect(Stub, :parse, fn [:return] -> @default_block end)

      BlockAnalyzer.run({__MODULE__, {:mfa_by_mfa, 1}, 10}, [:return], Stub)

      # wait till it's finished.
      assert @default_block == BlockCache.depend_on({__MODULE__, :mfa_by_mfa, 1})
      # check to make sure it can continue to be retrieved
      assert @default_block == BlockCache.depend_on({__MODULE__, :mfa_by_mfa, 1})
      # check to make sure it's been stored unde module/label
      assert @default_block == BlockCache.depend_on({__MODULE__, 10})
    end

    test "the result is retrievable from the block cache by label" do
      expect(Stub, :parse, fn [:return] -> @default_block end)

      BlockAnalyzer.run({__MODULE__, {:mfa_by_label, 1}, 11}, [:return], Stub)

      # wait till it's finished.
      assert @default_block == BlockCache.depend_on({__MODULE__, 11})
      # check to make sure it can continue to be retrieved
      assert @default_block == BlockCache.depend_on({__MODULE__, 11})
      # check to make sure it's been stored unde module/label
      assert @default_block == BlockCache.depend_on({__MODULE__, :mfa_by_label, 1})
    end
  end

  describe "when the analyzer is passed a label" do
    test "the result is retrievable from the block cache by label" do
      expect(Stub, :parse, fn [:return] -> @default_block end)

      BlockAnalyzer.run({__MODULE__, nil, 12}, [:return], Stub)

      # check to make sure it's been stored unde module/label
      assert @default_block == BlockCache.depend_on({__MODULE__, 12})
    end
  end

  describe "the analyzer can detect circular dependencies" do
    test "when there are two blocks that are dependent on each other" do
      test_pid = self()
      Stub
      |> expect(:parse, fn [:return] ->
        send(test_pid, :unblock)
        BlockCache.depend_on({__MODULE__, 14})
        @default_block
      end)
      |> expect(:parse, fn [:return] ->
        BlockCache.depend_on({__MODULE__, 13})
        @default_block
      end)

      BlockAnalyzer.run({__MODULE__, nil, 13}, [:return], Stub)
      Process.sleep(100)
      BlockAnalyzer.run({__MODULE__, nil, 14}, [:return], Stub)

      assert @default_block == BlockCache.depend_on({__MODULE__, 13})
    end

    test "when there are three blocks that are codependent" do
      test_pid = self()
      Stub
      |> expect(:parse, fn [:return] ->
        send(test_pid, :unblock)
        BlockCache.depend_on({__MODULE__, 16})
        @default_block
      end)
      |> expect(:parse, fn [:return] ->
        BlockCache.depend_on({__MODULE__, 17})
        @default_block
      end)
      |> expect(:parse, fn [:return] ->
        BlockCache.depend_on({__MODULE__, 15})
        @default_block
      end)

      BlockAnalyzer.run({__MODULE__, nil, 15}, [:return], Stub)
      Process.sleep(100)
      BlockAnalyzer.run({__MODULE__, nil, 16}, [:return], Stub)
      Process.sleep(100)
      BlockAnalyzer.run({__MODULE__, nil, 16}, [:return], Stub)

      assert @default_block == BlockCache.depend_on({__MODULE__, 15})
    end
  end

end
