defmodule Type.Inference.Opcodes.Gets do
  use Type.Inference.Opcodes

  alias Type.Inference.Module.ParallelParser

  opcode {:get_tuple_element, from, index, to} do
    forward(state, _meta, ...) do
      case fetch_type(state, from) do
        %Type.Tuple{elements: els} when length(els) > index ->
          {:ok, put_reg(state, to, Enum.at(els, index))}
        _ ->
          raise "get_tuple element #{inspect from} #{inspect index} #{inspect to} failed for #{state}"
      end
    end

    backprop :terminal
  end

  opcode {:get_list, from, head, tail} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, from) ->
          {:backprop, [put_reg(state, from, %Type.List{nonempty: true, final: builtin(:any)})]}
        true ->
          from_type = fetch_type(state, from)

          new_state = state
          |> put_reg(head, from_type.type)
          |> put_reg(tail, Type.union(from_type, from_type.final))

          {:ok, new_state}
      end
    end

    backprop :terminal
  end

  opcode {:get_tl, from, to} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, from) ->
          {:backprop, [put_reg(state, from, %Type.List{nonempty: true, final: builtin(:any)})]}
        true ->
          from_type = fetch_type(state, from)

          {:ok, put_reg(state, to, Type.union(from_type, from_type.final))}
      end
    end

    backprop :terminal
  end

end
