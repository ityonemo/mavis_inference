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

  default_block = [%Block{needs: %{}, makes: builtin(:any)}]
  @default_block default_block

  describe "when the analyzer is passed an export" do
    test "the result is retrievable from the block cache by mfa" do
      expect(Stub, :parse, fn [:return] -> @default_block end)

      BlockAnalyzer.run({__MODULE__, {:mfa_by_mfa, 1}, 10}, [:return], Stub)

      # wait till it's finished.
      assert @default_block == BlockCache.depend_on({__MODULE__, :mfa_by_mfa, 1}, strict: false)
      # check to make sure it can continue to be retrieved
      assert @default_block == BlockCache.depend_on({__MODULE__, :mfa_by_mfa, 1}, strict: false)
      # check to make sure it's been stored unde module/label
      assert @default_block == BlockCache.depend_on({__MODULE__, 10}, strict: false)
    end

    test "the result is retrievable from the block cache by label" do
      expect(Stub, :parse, fn [:return] -> @default_block end)

      BlockAnalyzer.run({__MODULE__, {:mfa_by_label, 1}, 11}, [:return], Stub)

      # wait till it's finished.
      assert @default_block == BlockCache.depend_on({__MODULE__, 11}, strict: false)
      # check to make sure it can continue to be retrieved
      assert @default_block == BlockCache.depend_on({__MODULE__, 11}, strict: false)
      # check to make sure it's been stored unde module/label
      assert @default_block == BlockCache.depend_on({__MODULE__, :mfa_by_label, 1}, strict: false)
    end
  end

  describe "when the analyzer is passed a label" do
    test "the result is retrievable from the block cache by label" do
      expect(Stub, :parse, fn [:return] -> @default_block end)

      BlockAnalyzer.run({__MODULE__, nil, 12}, [:return], Stub)

      # check to make sure it's been stored unde module/label
      assert @default_block == BlockCache.depend_on({__MODULE__, 12}, strict: false)
    end
  end

  describe "the analyzer can detect circular dependencies" do
    test "when there are two blocks that are dependent on each other" do
      test_pid = self()
      Stub
      |> expect(:parse, fn [:return] ->
        send(test_pid, :unblock)
        BlockCache.depend_on({__MODULE__, 14}, strict: false)
        @default_block
      end)
      |> expect(:parse, fn [:return] ->
        BlockCache.depend_on({__MODULE__, 13}, strict: false)
        @default_block
      end)

      BlockAnalyzer.run({__MODULE__, nil, 13}, [:return], Stub)
      Process.sleep(100)
      BlockAnalyzer.run({__MODULE__, nil, 14}, [:return], Stub)

      assert @default_block == BlockCache.depend_on({__MODULE__, 13}, strict: false)
    end

    test "when there are three blocks that are codependent" do
      test_pid = self()
      Stub
      |> expect(:parse, fn [:return] ->
        send(test_pid, :unblock)
        BlockCache.depend_on({__MODULE__, 16}, strict: false)
        @default_block
      end)
      |> expect(:parse, fn [:return] ->
        BlockCache.depend_on({__MODULE__, 17}, strict: false)
        @default_block
      end)
      |> expect(:parse, fn [:return] ->
        BlockCache.depend_on({__MODULE__, 15}, strict: false)
        @default_block
      end)

      BlockAnalyzer.run({__MODULE__, nil, 15}, [:return], Stub)
      Process.sleep(100)
      BlockAnalyzer.run({__MODULE__, nil, 16}, [:return], Stub)
      Process.sleep(100)
      BlockAnalyzer.run({__MODULE__, nil, 16}, [:return], Stub)

      assert @default_block == BlockCache.depend_on({__MODULE__, 15}, strict: false)
    end
  end

  describe "when in default strict mode, BlockAnalyzer" do

    defmodule RaiseTest do end

    test "will raise if a term with the module exists" do
      # create a tag indicating that the module has been added
      BlockCache.debug_add_module(RaiseTest)

      msg = "the module #{inspect RaiseTest} does not have function foo/1"
      assert_raise Type.InferenceError, msg, fn ->
        BlockCache.depend_on({RaiseTest, :foo, 1})
      end
    end

    defmodule AnalysisTest do
      @default_block default_block
      def run(module) do
        send(self(), {:block, {__MODULE__, :run, 1}, @default_block})
      end
    end

    test "will trigger a module analysis if it hasn't been analyzed yet" do
      # inject the dependency for module analysis launching.
      assert @default_block =
        BlockCache.depend_on(
          {AnalysisTest, :run, 1},
          module_analyzer: AnalysisTest)
    end
  end

end
