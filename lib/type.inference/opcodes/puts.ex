defmodule Type.Inference.Opcodes.Puts do
  use Type.Inference.Opcodes

  opcode {:put_list, head, tail, to} do
    forward(regs, _meta, ...) when not is_defined(regs, head) do
      {:backprop, [put_reg(regs, head, builtin(:any))]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, tail) do
      {:backprop, [put_reg(regs, tail, builtin(:any))]}
    end

    forward(regs, _meta, ...) do
      cond do
        match?(%Type.List{}, get_reg(regs, tail)) ->
          tail_type = get_reg(regs, tail)
          {:ok, put_reg(regs, to,
            %{tail_type |
              type: Type.union(get_reg(regs, head), tail_type.type),
              nonempty: true})}

        true ->
          {:ok, put_reg(regs, to,
            %Type.List{type: get_reg(regs, head),
                       nonempty: true,
                       final: get_reg(regs, tail)})}
      end
    end

    backprop :terminal
  end

  opcode {:put_tuple2, dest, {:list, list}} do
    forward(regs, _meta, ...) do
      try do
        Enum.each(list, fn
          reg when not is_defined(regs, reg) ->
            throw reg
          _ -> :ok
        end)

        tuple = %Type.Tuple{elements: Enum.map(list, &get_reg(regs, &1))}
        {:ok, put_reg(regs, dest, tuple)}
      catch
        res ->
          {:backprop, [put_reg(regs, res, builtin(:any))]}
      end
    end

    backprop :terminal
  end
end
