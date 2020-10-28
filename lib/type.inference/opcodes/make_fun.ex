defmodule Type.Inference.Opcodes.MakeFun do

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  opcode {:make_fun2, {module, fun, arity}, _, _, _} do
    # best guess:
    # ignore the last three terms.  Drops the mfa into register x0 always.
    forward(state = %{module: module}, _meta, ...) do
      return = fun
      |> ParallelParser.obtain_call(arity)
      |> Type.Inference.Block.to_function

      {:ok, put_reg(state, 0, return)}
    end

    forward :unimplemented
  end
end
