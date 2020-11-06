defmodule Type.Inference.Opcodes.Bifs do

  import Type, only: :macros

  use Type.Inference.Macros

  opcode {:bif, :self, :nofail, [], to} do
    forward(state, meta, ...) do
      {:ok, put_reg(state, to, builtin(:pid))}
    end

    backprop :terminal
  end

  opcode {:bif, :map_get, fail, [map, key], dest} do
    forward(state, meta, ...) do
      cond do
        (not is_defined(state, map)) and (not is_defined(state, key)) ->
          any_map = %Type.Map{optional: %{builtin(:any) => builtin(:any)}}
          {:backprop, [put_reg(state, map, any_map)]}

        not is_defined(state, map) ->
          key_type = fetch_type(state, key)
          map_type = %Type.Map{optional: %{key_type => builtin(:any)}}
          {:backprop, [put_reg(state, map, map_type)]}

        not is_defined(state, key) ->
          map_type = fetch_type(state, map)
          key_type = Type.Map.preimage(map_type)
          {:backprop, [put_reg(state, key, key_type)]}

        true ->
          key_type = fetch_type(state, key)
          map_type = fetch_type(state, map)
          res_type = Type.Map.apply(map_type, key_type)
          {:ok, put_reg(state, dest, res_type)}
      end
    end

    backprop :terminal
  end

  opcode {:bif, :>, _fail, [left, right], dest} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        not is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        true ->
          {:ok, put_reg(state, dest, builtin(:boolean))}
      end
    end

    backprop :terminal
  end

  opcode {:bif, :"=/=", _fail, [left, right], dest} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        not is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        true ->
          {:ok, put_reg(state, dest, builtin(:boolean))}
      end
    end

    backprop :terminal
  end

  # TODO: eliminate this with a function in mavis.
  defp type_at(%Type.Tuple{elements: :any}, _), do: builtin(:any)
  defp type_at(%Type.Tuple{elements: el}, index), do: Enum.at(el, index)

  defp tuple_el_union(%Type.Tuple{elements: :any}), do: builtin(:any)
  defp tuple_el_union(%Type.Tuple{elements: lst}), do: Type.union(lst)

  opcode {:bif, :element, _fail, [tuple, index], dest} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, tuple) ->
          {:backprop, [put_reg(state, tuple, %Type.Tuple{elements: :any})]}
        not is_defined(state, index) ->
          tuple = fetch_type(state, tuple)
          if is_list(tuple.elements) do
            {:backprop, [put_reg(state, index, 0..(length(tuple.elements) - 1))]}
          else
            {:backprop, [put_reg(state, index, builtin(:non_neg_integer))]}
          end
        is_integer(fetch_type(state, index)) ->
          {:ok, put_reg(state, dest, type_at(fetch_type(state, tuple), fetch_type(state, index)))}
        true ->
          # be better about this!
          {:ok, put_reg(state, dest, tuple_el_union(fetch_type(state, tuple)))}
      end
    end

    backprop :terminal
  end

  opcode {:bif, :node, :nofail, [], dest} do
    forward(state, _meta, ...) do
      {:ok, put_reg(state, dest, builtin(:node))}
    end

    backprop :terminal
  end

  opcode {:bif, :tuple_size, _fail, [from], to} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, from) ->
          {:backprop, [put_reg(state, from, %Type.Tuple{elements: :any})]}
        match?(%Type.Tuple{elements: :any}, fetch_type(state, from)) ->
          {:ok, put_reg(state, to, builtin(:non_neg_integer))}
        true ->
          {:ok, put_reg(state, to, length(fetch_type(state, from).elements))}
      end
    end

    backprop :terminal
  end

end
