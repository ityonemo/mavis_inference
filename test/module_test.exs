defmodule TypeTest.ModuleTest do
  use ExUnit.Case, async: true

  @moduletag :type_module

  alias Type.Function
  alias Type.Inference.Module

  import Type

  describe "when the module has an exported function via def" do
    test "from_binary/1 produces an entry point for an exported function" do
      {_, binary, _} = :code.get_object_code(TypeTest.ModuleExamples.WithDef)

      {:ok, module} = Module.from_binary(binary)

      assert %Module{entry_points: %{{:function, 1} => _ep}} = module
    end
  end

  describe "when the module has a private function via defp" do
    test "from_binary/1 produces an entry point for the private function" do
      {_, binary, _} = :code.get_object_code(TypeTest.ModuleExamples.WithDefp)

      {:ok, module} = Module.from_binary(binary)

      assert %Module{entry_points: %{{:functionp, 1} => _ep}} = module
    end
  end

  describe "when the module has a lambda" do
    test "from_binary/1 produces an entry point for the lambda" do
      {_, binary, _} = :code.get_object_code(TypeTest.ModuleExamples.WithLambda)

      {:ok, module} = Module.from_binary(binary)

      assert %Module{entry_points: %{{:"-fun.functionp/1-", 1} => _ep}} = module
    end
  end
end
