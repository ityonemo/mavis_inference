defmodule Type.Inference.Opcodes.MakeFun do

  use Type.Inference.Opcodes
  alias Type.Inference.Application.BlockCache

  opcode {:make_fun2, {module, fun, arity}, _, _, _} do
    # best guess:
    # ignore the last three terms.  Drops the mfa into register x0 always.
    forward(regs, _meta, ...) do

      return = {module, fun, arity}
      |> BlockCache.depend_on
      |> Type.Inference.Block.to_function

      {:ok, put_reg(regs, {:x, 0}, return)}
    end

    forward :unimplemented
  end
end
