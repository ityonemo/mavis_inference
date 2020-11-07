defmodule Type.Inference.Opcodes.Move do
  use Type.Inference.Opcodes

  # MOVE SEMANTICS

  opcode {:move, from = {:x, _}, to} do
    forward(state, _meta, ...) do
      if is_defined(state, from) do
        {:ok, put_reg(state, to, fetch_type(state, from))}
      else
        # we don't, a priori know what the datatype here is.
        {:backprop, [put_reg(state, from, builtin(:any))]}
      end
    end

    backprop(state, _meta, ...) do
      prev_state = state
      |> put_reg(from, fetch_type(state, to))
      |> tombstone(to)

      {:ok, [prev_state]}
    end
  end

  opcode {:move, value, to} do
    forward(state, _meta, ...) do
      {:ok, put_reg(state, to, fetch_type(state, value))}
    end
    backprop(state, _meta, ...) do
      {:ok, [tombstone(state, to)]}
    end
  end

  opcode {:swap, left, right} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}

        not is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}

        true ->
          end_state = state
          |> put_reg(right, fetch_type(state, left))
          |> put_reg(left, fetch_type(state, right))

          {:ok, end_state}
      end
    end
  end

end
