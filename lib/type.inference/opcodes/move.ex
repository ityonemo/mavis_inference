defmodule Type.Inference.Opcodes.Move do
  use Type.Inference.Opcodes

  # MOVE SEMANTICS

  opcode {:move, from = {:x, _}, to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      {:backprop, [put_reg(regs, from, builtin(:any))]}
    end

    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, to, get_reg(regs, from))}
    end

    backprop(out_regs, in_regs, _meta, ...) do
      prev_state = out_regs
      |> put_reg(from, get_reg(out_regs, to))
      |> tombstone(to)

      {:ok, prev_state}
    end
  end

  opcode {:move, value, to} do
    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, to, get_reg(regs, value))}
    end
    backprop(out_regs, in_regs, _meta, ...) do
      {:ok, tombstone(out_regs, to)}
    end
  end

  opcode {:swap, left, right} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, [put_reg(regs, left, builtin(:any))]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, [put_reg(regs, right, builtin(:any))]}
    end

    forward(regs, _meta, ...) do
      end_state = regs
      |> put_reg(right, get_reg(regs, left))
      |> put_reg(left, get_reg(regs, right))

      {:ok, end_state}
    end
  end

end
