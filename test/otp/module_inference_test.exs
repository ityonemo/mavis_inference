defmodule TypeTest.Inference.OTP.ModuleInferenceTest do
  use ExUnit.Case, async: true

  @moduletag :type_module

  alias Type.Function
  alias Type.Inference.Application.ModuleInference
  alias __MODULE__.BlockInference.Stub

  import Type

  defp common_setup(submodule) do
    {module, binary, _} = TypeTest.ModuleExamples
    |> Elixir.Module.concat(submodule)
    |> :code.get_object_code

    {:ok, binary: binary, module: module}
  end

  setup_all do
    Mox.defmock(Stub, for: Type.Inference.Application.BlockInference.Api)
    :ok
  end

  @any builtin(:any)

  @spec sweep :: %{label: [{module, :beam_asm.label}], mfa: [mfa]}
  defp sweep(map \\ %{label: [], mfa: []}) do
    receive do
      {:label, label} -> sweep(%{map | label: [label | map.label]})
      {:mfa, mfa} -> sweep(%{map | mfa: [mfa | map.mfa]})
    after
      0 -> map
    end
  end

  describe "when the module has an exported function via def, from_binary/1" do
    setup do
      common_setup(WithDef)
    end

    test "produces an entry point for an exported function", ctx do
      Mox.stub(Stub, :run, fn {mod, fa, label, _code} ->
        if fa, do: send(self(), {:mfa, fa})
        send(self(), {:label, {mod, label}})
        # unblock the function
        send(self(), {:block, {mod, label}, []})
      end)

      ModuleInference.infer(ctx.binary, ctx.module, Stub)

      assert {:function, 1} in sweep().mfa
    end
  end

  describe "when the module has a private function via defp, from_binary/1" do

    setup do
      common_setup(WithDefp)
    end

    test "produces an entry point for the private function", ctx do
      Mox.stub(Stub, :run, fn {mod, fa, label, _code} ->
        if fa, do: send(self(), {:mfa, fa})
        send(self(), {:label, {mod, label}})
        # unblock the function
        send(self(), {:block, {mod, label}, []})
      end)

      ModuleInference.infer(ctx.binary, ctx.module, Stub)

      assert {:functionp, 1} in sweep().mfa
    end
  end

  describe "when the module has a lambda, from_binary/1" do

    setup do
      common_setup(WithLambda)
    end

    test "produces an entry point for the lambda", ctx do
      Mox.stub(Stub, :run, fn {mod, fa, label, _code} ->
        if fa, do: send(self(), {:mfa, fa})
        send(self(), {:label, {mod, label}})
        # unblock the function
        send(self(), {:block, {mod, label}, []})
      end)

      ModuleInference.infer(ctx.binary, ctx.module, Stub)

      assert {:"-fun.functionp/1-", 1} in sweep().mfa
    end
  end
end
