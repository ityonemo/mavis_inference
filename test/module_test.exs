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

  @any builtin(:any)

  describe "when the module has an exported function via def, from_binary/1" do
    setup do
      common_setup(WithDef)
    end

    test "produces an entry point for an exported function", %{module: module} do
      assert %Module{entry_points: %{{:function, 1} => ep}} = module
    end

    test "produces a spec for the block", %{module: module} do
      [block] = Module.lookup(module, :function, 1)

      assert @any = block.makes
      assert %{0 => @any} = block.needs
    end
  end

  describe "when the module has a private function via defp, from_binary/1" do

    setup do
      common_setup(WithDefp)
    end

    test "produces an entry point for the private function", %{module: module} do
      assert %Module{entry_points: %{{:functionp, 1} => ep}} = module
    end

    test "produces a spec for the block", %{module: module} do
      [block] = Module.lookup(module, :function, 1)

      assert @any = block.makes
      assert %{0 => @any} = block.needs
    end
  end

  describe "when the module has a lambda, from_binary/1" do

    setup do
      common_setup(WithLambda)
    end

    test "produces an entry point for the lambda", %{module: module} do
      assert %Module{entry_points: %{{:"-fun.functionp/1-", 1} => ep}} = module
    end

    @empty_map %{}
    test "produces a spec for the block", %{module: module} do
      [block] = Module.lookup(module, :lambda, 0)

      assert %Type.Function{params: [@any], inferred: true, return: @any} =
        block.makes
      assert @empty_map = block.needs
    end
  end
end
