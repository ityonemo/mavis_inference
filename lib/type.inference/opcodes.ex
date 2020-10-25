defmodule Type.Inference.Opcodes do

  import Type, only: :macros

  use Type.Inference.Macros

  # MOVE SEMANTICS

  opcode {:move, {:x, from}, {:x, to}} do
    forward(state, ...) do
      if is_map_key(state.xreg, from) do
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

  opcode {:gc_bif, :bit_size, _, 1, [x: from], {:x, to}} do
    forward(state, ...) do
      if is_map_key(state.xreg, from) do
        {:ok, put_reg(state, 0, builtin(:non_neg_integer))}
      else
        prev_state = state
        |> tombstone(to)
        |> put_reg(from, %Type.Bitstring{size: 0, unit: 1})

        {:backprop, [prev_state]}
      end
    end

    backprop(state, ...) do
      raise "unimplemented"
    end
  end

  # TODO: make this not be as crazy
  @number Type.union(builtin(:float), builtin(:integer))

  opcode {:gc_bif, :+, {:f, to}, 2, [x: left, x: right], _} do
    forward(state, ...) do
      {:ok, put_reg(state, 0, @number)}
    end
    backprop :terminal
  end

  opcode {:select_val, {:x, from}, {:f, _fail}, {:list, list}} do
    :unimplemented
  end

  opcode {:call_ext_only, _arity, {:extfunc, mod, fun, abcd}} do
    :unimplemented
  end

  opcode {:make_fun2, {module, fun, arity}, _, _, _} do
    # best guess:
    # ignore the last three terms.  Drops the mfa into register x0 always.
    forward(state = %{module: module}, ...) do
      return = fun
      |> ParallelParser.obtain_call(arity)
      |> Type.Inference.Block.to_function

      {:ok, put_reg(state, 0, return)}
    end

    forward(_, ...) do
      raise "unimplemented"
    end
  end

  opcode :return do
    forward(state = %{xreg: %{0 => _type}}, ...) do
      {:ok, state}
    end
    forward(state = %{xreg: %{}}, ...) do
      {:backprop, [put_reg(state, 0, builtin(:any))]}
    end
    backprop :terminal
  end

  opcode {:line, _}

  opcode {:func_info, _, _, _} do
    forward(state, ...) do
      {:ok, put_reg(state, 0, builtin(:none))}
    end
    backprop :terminal
  end

  alias Type.Inference.Module.ParallelParser

  opcode {:call_only, _arity1, {_this_module, function, arity}} do
    forward(state, ...) do
      # TODO: allow this to take alternate specs
      [lookup] = ParallelParser.obtain_call(function, arity)

      # make sure that all of the "needs" are taken care of.
      lookup.needs
      |> Map.keys
      |> Enum.all?(&(&1 in Map.keys(state.xreg)))
      |> if do
        {:ok, put_reg(state, 0, lookup.makes)}
      else
        {:backprop, [merge_reg(state, lookup.needs)]}
      end
    end

    backprop :terminal
  end

  defp put_reg(state, reg, type) do
    %{state | xreg: Map.put(state.xreg, reg, type)}
  end
  defp get_reg(state, reg) do
    state.xreg[reg]
  end
  defp merge_reg(state, registers) do
    %{state | xreg: Map.merge(state.xreg, registers)}
  end
  defp tombstone(state, register) do
    %{state | xreg: Map.delete(state.xreg, register)}
  end
end
