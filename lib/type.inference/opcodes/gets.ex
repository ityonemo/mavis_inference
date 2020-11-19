defmodule Type.Inference.Opcodes.Gets do
  use Type.Inference.Opcodes

  opcode {:get_tuple_element, from, index, to} do
    forward(regs, _meta, ...) do
      case fetch_type(regs, from) do
        %Type.Tuple{elements: els} when length(els) > index ->
          {:ok, put_reg(regs, to, Enum.at(els, index))}
        _ ->
          raise "get_tuple element #{inspect from} #{inspect index} #{inspect to} failed for #{inspect regs}"
      end
    end

    backprop :terminal
  end

  opcode {:get_list, from, head, tail} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      {:backprop, [put_reg(regs, from, %Type.List{nonempty: true, final: builtin(:any)})]}
    end

    forward(regs, _meta, ...) do
      from_type = fetch_type(regs, from)

      new_state = regs
      |> put_reg(head, from_type.type)
      |> put_reg(tail, Type.union(from_type, from_type.final))

      {:ok, new_state}
    end

    backprop(out_regs, in_regs, _meta, ...) do

    end
  end

  opcode {:get_tl, from, to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      {:backprop, [put_reg(regs, from, %Type.List{nonempty: true, final: builtin(:any)})]}
    end

    forward(regs, _meta, ...) do
      from_type = fetch_type(regs, from)

      {:ok, put_reg(regs, to, Type.union(from_type, from_type.final))}
    end

    backprop :terminal
  end

  opcode {:get_hd, from, to}, :unimplemented

end
