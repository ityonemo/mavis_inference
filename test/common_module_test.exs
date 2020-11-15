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
    test "have __info__/1 function" do
      BlockCache.depend_on({@module, :__info__, 1})
    end

    test "have module_info/0 function" do
      {_mod, binary, _path} = :code.get_object_code(@empty_module)
      {:ok, module} = Type.Inference.Module.from_binary(binary)

      info_funs = Module.lookup(module, :module_info, 0)

      [%Type.Inference.Block{makes: builtin(:keyword), needs: %{}}] = info_funs
    end

    test "have module_info/1 function" do
      {_mod, binary, _path} = :code.get_object_code(@empty_module)
      {:ok, module} = Type.Inference.Module.from_binary(binary)

      info_funs = Module.lookup(module, :module_info, 1)

      Enum.each([:attributes, :compile, :exports, :native, :md5, :module], fn
        tag -> assert Enum.find(info_funs, &match?(%{needs: %{0 => ^tag}}, &1))
      end)
    end
  end
end
