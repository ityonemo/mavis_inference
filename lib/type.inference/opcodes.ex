defmodule Type.Inference.Opcodes do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.ParallelEngine

  opcode {:move, {:x, from}, {:x, to}} do
    forward(state) do
      {:ok, put_reg(state, to, get_reg(state, from))}
    end

    # this is a lie
    backprop :terminal
  end

  opcode {:move, nil, {:x, to}} do
    forward(state) do
      {:ok, put_reg(state, to, [])}
    end

    #this is a lie.
    backprop :terminal
  end

  opcode {:move, {:atom, atom}, {:x, to}} do
    forward(state) do
      {:ok, put_reg(state, to, atom)}
    end

    #this is a lie.
    backprop :terminal
  end

  opcode {:move, {:integer, value}, {:x, to}} do
    forward(state) do
      {:ok, put_reg(state, to, value)}
    end

    #this is a lie.
    backprop :terminal
  end


  opcode {:move, {:literal, literal}, {:x, to}} do
    forward(state) do
      {:ok, put_reg(state, to, Type.of(literal))}
    end

    # this is a lie.
    backprop :terminal
  end

  opcode {:gc_bif, :bit_size, _, 1, [x: from], {:x, to}} do
    forward(state) do
      {:ok, put_reg(state, 0, builtin(:non_neg_integer))}
    end

    #this is a lie.
    backprop :terminal
  end

  # TODO: make this not be as crazy
  @number Type.union(builtin(:float), builtin(:integer))

  opcode {:gc_bif, :+, {:f, to}, 2, [x: left, x: right], _} do
    forward(state) do
      {:ok, put_reg(state, 0, @number)}
    end
    backprop :terminal
  end

  opcode {:select_val, {:x, from}, {:f, _fail}, {:list, list}} do
    forward(reg) do
      # first make sure
      list
      |> Enum.chunk_every(2)
      |> Enum.reduce(reg, &reduce_select/2)
    end
    backprop :terminal
  end

  defp reduce_select([_what, f: jump], _reg) do
    ParallelEngine.obtain_label(jump)
    |> IO.inspect(label: "75")
    raise "yoyo"
  end

  opcode {:call_ext_only, _arity, {:extfunc, mod, fun, abcd}} do
    forward(state) do
      # currently, be shitty.
      {:ok, put_reg(state, 0, builtin(:any))}
    end

    # temporary, definitely a lie.
    backprop :terminal
  end

  opcode {:make_fun2, {module, fun, arity}, _, _, _} do
    forward(state) do
      # for now, just do this dumb thing.
      # TODO: make sure that we know which register the result is placed in.
      any_fun = %Type.Function{params: [builtin(:any)], return: builtin(:any)}
      {:ok, put_reg(state, 0, any_fun)}
    end
  end

  opcode :return do
    forward(state = %{xreg: %{0 => _type}}) do
      {:ok, state}
    end
    forward(state = %{xreg: %{}}) do
      {:backprop, [put_reg(state, 0, builtin(:any))]}
    end
    backprop :terminal
  end

  opcode {:line, _}

  opcode {:func_info, _, _, _} do
    forward(state) do
      {:ok, put_reg(state, 0, builtin(:none))}
    end
    backprop :terminal
  end

  defp put_reg(state, reg, type) do
    %{state | xreg: Map.put(state.xreg, reg, type)}
  end
  defp get_reg(state, reg) do
    state.xreg[reg]
  end
end
