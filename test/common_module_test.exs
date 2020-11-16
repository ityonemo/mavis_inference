defmodule TypeTest.CommonModuleTest do
  use ExUnit.Case, async: true

  @module TypeTest.ModuleExamples.Empty

  import Type

  alias Type.Inference.Application.{BlockCache, ModuleAnalyzer}

  setup_all do
    ModuleAnalyzer.run(@module)
    :ok
  end

  describe "basic modules" do

    test "make sure the following functions have expected types"

    test "have __info__/1 function" do
      assert BlockCache.depend_on({@module, :__info__, 1})
    end

    test "have module_info/0 function" do
      assert BlockCache.depend_on({@module, :module_info, 0})
    end

    test "have module_info/1 function" do
      assert BlockCache.depend_on({@module, :module_info, 1})
    end
  end
end
