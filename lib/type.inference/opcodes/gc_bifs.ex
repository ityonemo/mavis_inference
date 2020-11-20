defmodule Type.Inference.Opcodes.GcBifs do
  use Type.Inference.Opcodes

  def bs_to_size(%Type.Bitstring{unit: 0, size: size}), do: size
  def bs_to_size(%Type.Bitstring{size: 0}), do: builtin(:non_neg_integer)
  def bs_to_size(%Type.Bitstring{}), do: builtin(:pos_integer)

  def size_to_bs(i) when is_integer(i), do: %Type.Bitstring{size: i}
  def size_to_bs(builtin(:pos_integer)), do: %Type.Bitstring{size: 1, unit: 1}
  def size_to_bs(enumerable) do
    enumerable  # range or union
    |> Enum.map(&size_to_bs/1)
    |> Type.union
  end

  opcode {:gc_bif, :bit_size, _, _, [from], to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      prev_state = regs
      |> tombstone(to)
      |> put_reg(from, %Type.Bitstring{size: 0, unit: 1})

      {:backprop, [prev_state]}
    end

    forward(regs, _meta, ...) do
      case get_reg(regs, from) do
        bs = %Type.Bitstring{} ->
          {:ok, put_reg(regs, to, bs_to_size(bs))}
        %Type.Union{of: bitstrings} ->
          # TODO: make this do more work
          sizes = bitstrings
          |> Enum.map(&bs_to_size(&1))
          |> Type.union

          {:ok, put_reg(regs, to, sizes)}
      end
    end

    backprop(out_regs, in_regs, _meta, ...) do
      bs_type = size_to_bs(get_reg(out_regs, to))
      {:ok, put_reg(in_regs, from, bs_type)}
    end
  end

  opcode {:gc_bif, :byte_size, _, _, [from], to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      prev_state = regs
      |> tombstone(to)
      |> put_reg(from, %Type.Bitstring{size: 0, unit: 8})

      {:backprop, [prev_state]}
    end

    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, to, builtin(:non_neg_integer))}
    end

    backprop(out_regs, in_regs, _meta, ...) do
      IO.puts("hi dad")
      raise "foo"
    #  if Type.subtype?(get_reg(regs, to), builtin(:non_neg_integer)) do
    #    {:ok, put_reg(regs, from, %Type.Bitstring{size: 0, unit: 1})}
    #  else
    #    {:ok, []}
    #  end
    end
  end

  opcode {:gc_bif, :length, _fail, _, [from], to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      {:backprop, [put_reg(regs, from, %Type.List{})]}
    end

    forward(regs, _meta, ...) when is_reg(regs, from, []) do
      {:ok, put_reg(regs, to, 0)}
    end

    forward(regs, _meta, ...) do
      cond do
        match?(%Type.List{nonempty: true}, get_reg(regs, from)) ->
          {:ok, put_reg(regs, to, builtin(:pos_integer))}
        match?(%Type.List{}, get_reg(regs, from)) ->
          {:ok, put_reg(regs, to, builtin(:non_neg_integer))}
      end
    end

    backprop :terminal
  end

  opcode {:gc_bif, :map_size, _fail, _, [from], to} do
    forward(regs, _meta, ...) when not is_defined(regs, from) do
      prev_state = regs
      |> tombstone(to)
      |> put_reg(from, %Type.Map{optional: %{builtin(:any) => builtin(:any)}})

      {:backprop, [prev_state]}
    end

    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, to, builtin(:non_neg_integer))}
    end

    backprop :terminal
  end

  # TODO: make this not be as crazy
  @int_types [builtin(:pos_integer), 0, builtin(:neg_integer)]
  @num_types [builtin(:float) | @int_types]
  @quotient_types [builtin(:pos_integer), builtin(:neg_integer)]

  @add_fn Type.union([
    %Type.Function{params: [builtin(:float),       builtin(:integer)],     return: builtin(:float)},
    %Type.Function{params: [builtin(:integer),     builtin(:float)],       return: builtin(:float)},
    %Type.Function{params: [builtin(:float),       builtin(:float)],       return: builtin(:float)},
    %Type.Function{params: [builtin(:pos_integer), builtin(:pos_integer)], return: builtin(:pos_integer)},
    %Type.Function{params: [builtin(:pos_integer), 0],                     return: builtin(:pos_integer)},
    %Type.Function{params: [builtin(:pos_integer), builtin(:neg_integer)], return: builtin(:integer)},
    %Type.Function{params: [0,                     builtin(:pos_integer)], return: builtin(:pos_integer)},
    %Type.Function{params: [0,                     0],                     return: 0},
    %Type.Function{params: [0,                     builtin(:neg_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [builtin(:neg_integer), builtin(:pos_integer)], return: builtin(:integer)},
    %Type.Function{params: [builtin(:neg_integer), 0],                     return: builtin(:neg_integer)},
    %Type.Function{params: [builtin(:neg_integer), builtin(:neg_integer)], return: builtin(:neg_integer)}
  ])

  opcode {:gc_bif, :+, _, _, [left, right], to} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, Enum.map(@num_types, &put_reg(regs, left, &1))}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, Enum.map(@num_types, &put_reg(regs, right, &1))}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) and is_reg(regs, left, builtin(:integer)) do
      {:backprop, [put_reg(regs, right, builtin(:float))]}
    end

    forward(regs, _meta, ...) do
      ltype = get_reg(regs, left)
      rtype = get_reg(regs, right)
      {:ok, res} = Type.Function.apply_types(@add_fn, [ltype, rtype])
      {:ok, put_reg(regs, to, res)}
    end

    # a temporary lie.
    backprop :terminal
  end

  @sub_fn Type.union([
    %Type.Function{params: [builtin(:float),       builtin(:integer)],     return: builtin(:float)},
    %Type.Function{params: [builtin(:integer),     builtin(:float)],       return: builtin(:float)},
    %Type.Function{params: [builtin(:float),       builtin(:float)],       return: builtin(:float)},
    %Type.Function{params: [builtin(:pos_integer), builtin(:pos_integer)], return: builtin(:integer)},
    %Type.Function{params: [builtin(:pos_integer), 0],                     return: builtin(:pos_integer)},
    %Type.Function{params: [builtin(:pos_integer), builtin(:neg_integer)], return: builtin(:pos_integer)},
    %Type.Function{params: [0,                     builtin(:pos_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [0,                     0],                     return: 0},
    %Type.Function{params: [0,                     builtin(:neg_integer)], return: builtin(:pos_integer)},
    %Type.Function{params: [builtin(:neg_integer), builtin(:pos_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [builtin(:neg_integer), 0],                     return: builtin(:neg_integer)},
    %Type.Function{params: [builtin(:neg_integer), builtin(:neg_integer)], return: builtin(:integer)}
  ])

  opcode {:gc_bif, :-, _, _, [left, right], to} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, Enum.map(@num_types, &put_reg(regs, left, &1))}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, Enum.map(@num_types, &put_reg(regs, right, &1))}
    end

    forward(regs, _meta, ...) do
      ltype = get_reg(regs, left)
      rtype = get_reg(regs, right)
      {:ok, res} = Type.Function.apply_types(@sub_fn, [ltype, rtype])
      {:ok, put_reg(regs, to, res)}
    end

    # a temporary lie.
    backprop :terminal
  end

  @mul_fn Type.union([
    %Type.Function{params: [builtin(:float),       builtin(:integer)],     return: builtin(:float)},
    %Type.Function{params: [builtin(:integer),     builtin(:float)],       return: builtin(:float)},
    %Type.Function{params: [builtin(:float),       builtin(:float)],       return: builtin(:float)},
    %Type.Function{params: [builtin(:pos_integer), builtin(:pos_integer)], return: builtin(:pos_integer)},
    %Type.Function{params: [builtin(:pos_integer), 0],                     return: 0},
    %Type.Function{params: [builtin(:pos_integer), builtin(:neg_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [0,                     builtin(:pos_integer)], return: 0},
    %Type.Function{params: [0,                     0],                     return: 0},
    %Type.Function{params: [0,                     builtin(:neg_integer)], return: 0},
    %Type.Function{params: [builtin(:neg_integer), builtin(:pos_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [builtin(:neg_integer), 0],                     return: 0},
    %Type.Function{params: [builtin(:neg_integer), builtin(:neg_integer)], return: builtin(:pos_integer)}
  ])

  opcode {:gc_bif, :*, _, _, [left, right], to} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, Enum.map(@num_types, &put_reg(regs, left, &1))}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, Enum.map(@num_types, &put_reg(regs, right, &1))}
    end

    forward(regs, _meta, ...) do
      ltype = get_reg(regs, left)
      rtype = get_reg(regs, right)
      {:ok, res} = Type.Function.apply_types(@mul_fn, [ltype, rtype])
      {:ok, put_reg(regs, to, res)}
    end

    # a temporary lie.
    backprop :terminal
  end

  @div_fn Type.union([
    %Type.Function{params: [builtin(:pos_integer), builtin(:pos_integer)], return: builtin(:pos_integer)},
    %Type.Function{params: [builtin(:pos_integer), builtin(:neg_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [0,                     builtin(:pos_integer)], return: 0},
    %Type.Function{params: [0,                     builtin(:neg_integer)], return: 0},
    %Type.Function{params: [builtin(:neg_integer), builtin(:pos_integer)], return: builtin(:neg_integer)},
    %Type.Function{params: [builtin(:neg_integer), builtin(:neg_integer)], return: builtin(:pos_integer)}
  ])

  opcode {:gc_bif, :div, _, _, [left, right], to} do
    forward(regs, _meta, ...) when not is_defined(regs, left) do
      {:backprop, Enum.map(@int_types, &put_reg(regs, left, &1))}
    end

    forward(regs, _meta, ...) when not is_defined(regs, right) do
      {:backprop, Enum.map(@quotient_types, &put_reg(regs, right, &1))}
    end

    forward(regs, _meta, ...) do
      ltype = get_reg(regs, left)
      rtype = get_reg(regs, right)
      {:ok, res} = Type.Function.apply_types(@div_fn, [ltype, rtype])
      {:ok, put_reg(regs, to, res)}
    end

    # a temporary lie.
    backprop :terminal
  end

end
