defmodule Type.Inference.Opcodes.Puts do
  use Type.Inference.Opcodes

  opcode {:put_list, head, tail, to} do
    forward(state, _meta, ...) do
      cond do
        ! is_defined(state, head) ->
          {:backprop, [put_reg(state, head, builtin(:any))]}
        ! is_defined(state, tail) ->
          {:backprop, [put_reg(state, tail, builtin(:any))]}

        # TODO: consolidate this when we get correctly working when clauses.
        match?(%Type.List{}, fetch_type(state, tail)) ->
          tail_type = fetch_type(state, tail)
          {:ok, put_reg(state, to,
            %{tail_type |
              type: Type.union(fetch_type(state, head), tail_type.type),
              nonempty: true})}

        true ->
          {:ok, put_reg(state, to,
            %Type.List{type: fetch_type(state, head),
                       nonempty: true,
                       final: fetch_type(state, tail)})}
      end
    end

    backprop :terminal
  end

  opcode {:put_tuple2, dest, {:list, list}} do
    forward(state, _meta, ...) do
      try do
        Enum.each(list, fn
          reg when not is_defined(state, reg) ->
            throw reg
          _ -> :ok
        end)

        tuple = %Type.Tuple{elements: Enum.map(list, &fetch_type(state, &1))}
        {:ok, put_reg(state, dest, tuple)}
      catch
        res ->
          {:backprop, [put_reg(state, res, builtin(:any))]}
      end
    end

    backprop :terminal
  end
end
