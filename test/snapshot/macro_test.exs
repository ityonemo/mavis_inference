defmodule TypeTest.Snapshot.MacroTest do

  use ExUnit.Case, async: true

  describe "Macros.get_variables/1 can find variables from" do
    test "forward function body" do
      q = quote do
        return = fun
        |> ParallelParser.obtain_call(arity)
        |> Type.Inference.Block.to_function

        {:ok, put_reg(state, 0, return)}
      end

      vars = Type.Inference.Macros.get_variables(q)

      assert :fun in vars
      assert :return in vars
      assert :arity in vars
    end
  end
end
