defmodule TypeTest.ModuleTest do
  use ExUnit.Case, async: true

  @moduletag :type_module

  alias Type.Function
  alias Type.Inference.Module

  import Type

  defp common_setup(submodule) do
    {_, binary, _} = TypeTest.ModuleExamples
    |> Elixir.Module.concat(submodule)
    |> :code.get_object_code

    {:ok, module_struct} = Module.from_binary(binary)
    {:ok, module: module_struct}
  end

  describe "when the module has an exported function via def, from_binary/1" do

    setup do
      common_setup(WithDef)
    end

    test "produces an entry point for an exported function" , %{module: module} do
      assert %Module{entry_points: %{{:function, 1} => ep}} = module

      assert [block] = module.label_blocks[ep]

      assert %{0 => builtin(:any)} = block.makes.xreg
      assert %{0 => builtin(:any)} = block.needs.xreg
    end
  end

  describe "when the module has a private function via defp, from_binary/1" do

    setup do
      common_setup(WithDefp)
    end

    test "produces an entry point for the private function", %{module: module} do
      assert %Module{entry_points: %{{:functionp, 1} => _ep}} = module
    end
  end

  describe "when the module has a lambda, from_binary/1" do

    setup do
      common_setup(WithLambda)
    end

    test "produces an entry point for the lambda", %{module: module} do
      assert %Module{entry_points: %{{:"-fun.functionp/1-", 1} => _ep}} = module
    end
  end
end
