defmodule Type.Inference.Opcodes.Move do

  import Type, only: :macros

  use Type.Inference.Macros

  # MOVE SEMANTICS

  opcode {:move, {:x, from}, {:x, to}} do
    forward(state, ...) do
      if is_map_key(state.x, from) do
        {:ok, put_reg(state, to, get_reg(state, from))}
      else
        # we don't, a priori know what the datatype here is.
        {:backprop, [put_reg(state, from, builtin(:any))]}
      end
    end

    backprop(state, ...) do
      prev_state = state
      |> put_reg(from, get_reg(state, to))
      |> tombstone(to)

      {:ok, [prev_state]}
    end
  end

  opcode {:move, value, {:x, to}} do
    forward(state, ...) do
      {:ok, put_reg(state, to, type_of(value))}
    end
    backprop(state, ...) do
      {:ok, [tombstone(state, to)]}
    end
  end

  defp type_of(nil), do: []
  defp type_of({_, value}), do: Type.of(value)

end
