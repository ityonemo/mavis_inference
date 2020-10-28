defmodule TypeTest.CommonModuleTest do
  use ExUnit.Case, async: true

  @empty_module TypeTest.ModuleExamples.Empty

  import Type

  alias Type.Inference.Module

  describe "basic modules" do
    test "have __info__/1 function" do

      {_mod, binary, _path} = :code.get_object_code(@empty_module)
      {:ok, module} = Type.Inference.Module.from_binary(binary)

      info_funs = Module.lookup(module, :__info__, 1)

      Enum.each([:attributes, :compile, :deprecated, :functions, :macros, :md5, :module], fn
        tag -> assert Enum.find(info_funs, &match?(%{needs: %{0 => ^tag}}, &1))
      end)
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
