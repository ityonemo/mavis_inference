defmodule Type.Inference.Opcodes.Bifs do
  use Type.Inference.Opcodes

  opcode {:bif, :self, :nofail, [], to} do
    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, to, builtin(:pid))}
    end

    backprop :terminal
  end

  opcode {:bif, :map_get, fail, [map, key], dest} do
    forward(regs, _meta, ...)
      when not is_defined(regs, map) and not is_defined(regs, key) do
      any_map = %Type.Map{optional: %{builtin(:any) => builtin(:any)}}
      {:backprop, [put_reg(regs, map, any_map)]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, map) do
      key_type = get_reg(regs, key)
      map_type = %Type.Map{optional: %{key_type => builtin(:any)}}
      {:backprop, [put_reg(regs, map, map_type)]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, key) do
      map_type = get_reg(regs, map)
      key_type = Type.Map.preimage(map_type)
      {:backprop, [put_reg(regs, key, key_type)]}
    end

    forward(regs, _meta, ...) do
      key_type = get_reg(regs, key)
      map_type = get_reg(regs, map)
      res_type = Type.Map.apply(map_type, key_type)
      {:ok, put_reg(regs, dest, res_type)}
    end

    backprop :terminal
  end

  opcode {:bif, :>, _fail, [left, right], dest} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, [put_reg(regs, left, builtin(:any))]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, [put_reg(regs, right, builtin(:any))]}
    end

    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, dest, builtin(:boolean))}
    end

    backprop :terminal
  end

  opcode {:bif, :"=/=", _fail, [left, right], dest} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, [put_reg(regs, left, builtin(:any))]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, [put_reg(regs, right, builtin(:any))]}
    end

    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, dest, builtin(:boolean))}
    end

    backprop :terminal
  end

  # TODO: eliminate this with a function in mavis.
  defp type_at(%Type.Tuple{elements: {:min, _}}, _), do: builtin(:any)
  defp type_at(%Type.Tuple{elements: el}, index), do: Enum.at(el, index)

  defp tuple_el_union(%Type.Tuple{elements: {:min, _}}), do: builtin(:any)
  defp tuple_el_union(%Type.Tuple{elements: lst}), do: Type.union(lst)

  opcode {:bif, :element, _fail, [tuple, index], dest} do
    forward(regs, _meta, ...) when not is_defined(regs, tuple) do
      {:backprop, [put_reg(regs, tuple, %Type.Tuple{elements: {:min, 0}})]}
    end

    forward(regs, _meta, ...) when not is_defined(regs, index) do
      case get_reg(regs, tuple).elements do
        lst when is_list(lst) ->
          {:backprop, [put_reg(regs, index, 0..(length(lst) - 1))]}
        {:min, 0} ->
          {:backprop, [put_reg(regs, index, builtin(:non_neg_integer))]}
        # also add {:min, number}
      end
    end

    forward(regs, _meta, ...) do
      if is_integer(get_reg(regs, index)) do
        {:ok, put_reg(regs, dest, type_at(get_reg(regs, tuple), get_reg(regs, index)))}
      else
        # be better about this!
        {:ok, put_reg(regs, dest, tuple_el_union(get_reg(regs, tuple)))}
      end
    end

    backprop :terminal
  end

  opcode {:bif, :node, :nofail, [], dest} do
    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, dest, builtin(:node))}
    end

    backprop :terminal
  end

  opcode {:bif, :node, _fail, [from], dest} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      {:backprop, [put_reg(regs, from, builtin(:identifier))]}
    end

    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, dest, builtin(:node))}
    end

    backprop :terminal
  end


  opcode {:bif, :tuple_size, _fail, [from], to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      {:backprop, [put_reg(regs, from, %Type.Tuple{elements: {:min, 0}})]}
    end

    forward(regs, _meta, ...) do
      if match?(%Type.Tuple{elements: {:min, 0}}, get_reg(regs, from)) do
        {:ok, put_reg(regs, to, builtin(:non_neg_integer))}
      else
        {:ok, put_reg(regs, to, length(get_reg(regs, from).elements))}
      end
    end

    backprop :terminal
  end

end
