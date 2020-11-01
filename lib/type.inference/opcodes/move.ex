defmodule Type.Inference.Opcodes.Move do

  import Type, only: :macros

  use Type.Inference.Macros

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

end
