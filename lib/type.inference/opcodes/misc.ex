defmodule Type.Inference.Opcodes.Misc do

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  opcode {:line, _}, :noop

  opcode {:allocate, _, _}, :noop

  opcode {:allocate_zero, _, _}, :noop

  opcode {:init, _}, :noop

  opcode {:test_heap, _, _}, :noop

  opcode {:jump, {:f, dest}} do
    forward(state, _meta, ...) do
      [jump_blk] = ParallelParser.obtain_label(dest)

      if reg = Enum.find(Map.keys(jump_blk.needs), &(!is_map_key(state.x, &1))) do
        {:backprop, [put_reg(state, reg, jump_blk.needs[reg])]}
      else
        {:ok, put_reg(state, 0, jump_blk.makes)}
      end
    end

    backprop :terminal
  end
end
