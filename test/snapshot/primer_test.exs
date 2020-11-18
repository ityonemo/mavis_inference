defmodule TypeTest.Snapshot.PrimerTest do
  # examples from https://blog.erlang.org/a-brief-BEAM-primer/

  use ExUnit.Case, async: true

  alias Type.Inference

  describe "for the beam primer example" do
    test "sum_tail/2 function is correctly typed" do

      Type.Inference.Debug.dump_module(TypeTest.PrimerExamples)

      assert {:ok, type} = Type.Inference.infer(TypeTest.PrimerExamples, :sum_tail, 2)

      type
      |> IO.inspect(label: "17")
    end
    test "sum_tail/1 function is correctly typed" do
      assert {:ok, type} = Type.Inference.infer(TypeTest.PrimerExamples, :sum_tail, 1)

      type
      |> IO.inspect(label: "19")
    end
  end
end
