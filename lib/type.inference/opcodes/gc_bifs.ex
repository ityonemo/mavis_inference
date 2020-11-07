defmodule Type.Inference.Opcodes.GcBifs do
  use Type.Inference.Opcodes

  opcode {:gc_bif, :bit_size, _, _, [from], to} do
    forward(state, _meta, ...) do
      if is_defined(state, from) do
        {:ok, put_reg(state, to, builtin(:non_neg_integer))}
      else
        prev_state = state
        |> tombstone(to)
        |> put_reg(from, %Type.Bitstring{size: 0, unit: 1})

        {:backprop, [prev_state]}
      end
    end

    backprop(state, _meta, ...) do
      if Type.subtype?(fetch_type(state, to), builtin(:non_neg_integer)) do
        {:ok, [put_reg(state, from, %Type.Bitstring{size: 0, unit: 1})]}
      else
        {:ok, []}
      end
    end
  end

  opcode {:gc_bif, :byte_size, _, _, [from], to} do
    forward(state, _meta, ...) do
      if is_defined(state, from) do
        {:ok, put_reg(state, to, builtin(:non_neg_integer))}
      else
        prev_state = state
        |> tombstone(to)
        |> put_reg(from, %Type.Bitstring{size: 0, unit: 8})

        {:backprop, [prev_state]}
      end
    end

    backprop(state, _meta, ...) do
      if Type.subtype?(fetch_type(state, to), builtin(:non_neg_integer)) do
        {:ok, [put_reg(state, from, %Type.Bitstring{size: 0, unit: 1})]}
      else
        {:ok, []}
      end
    end
  end

  opcode {:gc_bif, :length, _fail, _, [from], to} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, from) ->
          {:backprop, [put_reg(state, from, %Type.List{})]}
        fetch_type(state, from) == [] -> {:ok, put_reg(state, to, 0)}
        match?(%Type.List{nonempty: true}, fetch_type(state, from)) ->
          {:ok, put_reg(state, to, builtin(:pos_integer))}
        match?(%Type.List{}, fetch_type(state, from)) ->
          {:ok, put_reg(state, to, builtin(:non_neg_integer))}
      end
    end

    backprop :terminal
  end

  opcode {:gc_bif, :map_size, _fail, _, [from], to} do
    forward(state, _meta, ...) do
      if is_defined(state, from) do
        {:ok, put_reg(state, to, builtin(:non_neg_integer))}
      else
        prev_state = state
        |> tombstone(to)
        |> put_reg(from, %Type.Map{optional: %{builtin(:any) => builtin(:any)}})

        {:backprop, [prev_state]}
      end
    end

    backprop :terminal
  end

  # TODO: make this not be as crazy
  @int_types [builtin(:pos_integer), 0, builtin(:neg_integer)]
  @num_types [builtin(:float), builtin(:integer)]
  @all_int_types [builtin(:integer), builtin(:non_neg_integer) | @int_types]

  # there is probably a better way to do this.
  defp do_add(0,                     any),                           do: any
  defp do_add(any,                   0),                             do: any
  defp do_add(builtin(:non_neg_integer), builtin(:non_neg_integer)), do: builtin(:non_neg_integer)
  defp do_add(builtin(:non_neg_integer), builtin(:pos_integer)),     do: builtin(:pos_integer)
  defp do_add(builtin(:non_neg_integer), builtin(:neg_integer)),     do: builtin(:integer)
  defp do_add(builtin(:pos_integer),     builtin(:non_neg_integer)), do: builtin(:pos_integer)
  defp do_add(builtin(:pos_integer),     builtin(:pos_integer)),     do: builtin(:pos_integer)
  defp do_add(builtin(:pos_integer),     builtin(:neg_integer)),     do: builtin(:integer)
  defp do_add(builtin(:neg_integer),     builtin(:non_neg_integer)), do: builtin(:integer)
  defp do_add(builtin(:neg_integer),     builtin(:pos_integer)),     do: builtin(:integer)
  defp do_add(builtin(:neg_integer),     builtin(:neg_integer)),     do: builtin(:neg_integer)
  defp do_add(builtin(:integer),         builtin(:integer)),         do: builtin(:integer)
  defp do_add(_,                         builtin(:float)),           do: builtin(:float)
  defp do_add(builtin(:float),           _),                         do: builtin(:float)
  defp do_add(t, builtin(:integer)) when t in @all_int_types,        do: builtin(:integer)
  defp do_add(builtin(:integer), t) when t in @all_int_types,        do: builtin(:integer)

  opcode {:gc_bif, :+, _, _, [left, right], to} do
    forward(state, _meta, ...) do
      cond do
        # TODO: make this a guard.
        not is_defined(state, left) ->
          {:backprop, Enum.map(@int_types ++ @num_types, &put_reg(state, left, &1))}
        not is_defined(state, right) and fetch_type(state, left) in @int_types ->
          {:backprop, Enum.map(@int_types, &put_reg(state, right, &1))}
        not is_defined(state, right) and fetch_type(state, left) == builtin(:float) ->
          {:backprop, [put_reg(state, right, builtin(:float)), put_reg(state, right, builtin(:integer))]}
        not is_defined(state, right) and fetch_type(state, left) == builtin(:integer) ->
          {:backprop, [put_reg(state, right, builtin(:float))]}
        true ->
          ltype = fetch_type(state, left)
          rtype = fetch_type(state, right)
          res = do_add(ltype, rtype)
          {:ok, put_reg(state, to, res)}
      end
    end

    # a temporary lie.
    backprop :terminal
  end

  defp do_sub(0,                         builtin(:non_neg_integer)), do: Type.union(builtin(:neg_integer), 0)
  defp do_sub(0,                         builtin(:pos_integer)),     do: builtin(:neg_integer)
  defp do_sub(0,                         builtin(:neg_integer)),     do: builtin(:pos_integer)
  defp do_sub(any,                       0),                         do: any
  defp do_sub(builtin(:non_neg_integer), builtin(:non_neg_integer)), do: builtin(:integer)
  defp do_sub(builtin(:non_neg_integer), builtin(:pos_integer)),     do: builtin(:integer)
  defp do_sub(builtin(:non_neg_integer), builtin(:neg_integer)),     do: builtin(:pos_integer)
  defp do_sub(builtin(:pos_integer),     builtin(:non_neg_integer)), do: builtin(:integer)
  defp do_sub(builtin(:pos_integer),     builtin(:pos_integer)),     do: builtin(:integer)
  defp do_sub(builtin(:pos_integer),     builtin(:neg_integer)),     do: builtin(:pos_integer)
  defp do_sub(builtin(:neg_integer),     builtin(:non_neg_integer)), do: builtin(:neg_integer)
  defp do_sub(builtin(:neg_integer),     builtin(:pos_integer)),     do: builtin(:neg_integer)
  defp do_sub(builtin(:neg_integer),     builtin(:neg_integer)),     do: builtin(:integer)
  defp do_sub(builtin(:integer),         builtin(:integer)),         do: builtin(:integer)
  defp do_sub(_,                         builtin(:float)),           do: builtin(:float)
  defp do_sub(builtin(:float),           _),                         do: builtin(:float)
  defp do_sub(t, builtin(:integer)) when t in @all_int_types,        do: builtin(:integer)
  defp do_sub(builtin(:integer), t) when t in @all_int_types,        do: builtin(:integer)

  opcode {:gc_bif, :-, _, _, [left, right], to} do
    forward(state, _meta, ...) do
      cond do
        # TODO: make this a guard.
        not is_defined(state, left) ->
          {:backprop, Enum.map(@int_types ++ @num_types, &put_reg(state, left, &1))}
        not is_defined(state, right) and fetch_type(state, left) in @int_types ->
          {:backprop, Enum.map(@int_types, &put_reg(state, right, &1))}
        not is_defined(state, right) and fetch_type(state, left) == builtin(:float) ->
          {:backprop, [put_reg(state, right, builtin(:float)), put_reg(state, right, builtin(:integer))]}
        not is_defined(state, right) and fetch_type(state, left) == builtin(:integer) ->
          {:backprop, [put_reg(state, right, builtin(:float))]}
        true ->
          ltype = fetch_type(state, left)
          rtype = fetch_type(state, right)
          res = do_sub(ltype, rtype)
          {:ok, put_reg(state, to, res)}
      end
    end

    # a temporary lie.
    backprop :terminal
  end

  # there is probably a better way to do this.
  defp do_mul(0,                     _any),                          do: 0
  defp do_mul(_any,                   0),                            do: 0
  defp do_mul(builtin(:non_neg_integer), builtin(:non_neg_integer)), do: builtin(:non_neg_integer)
  defp do_mul(builtin(:non_neg_integer), builtin(:pos_integer)),     do: builtin(:non_neg_integer)
  defp do_mul(builtin(:non_neg_integer), builtin(:neg_integer)),     do: Type.union(builtin(:neg_integer), 0)
  defp do_mul(builtin(:pos_integer),     builtin(:non_neg_integer)), do: builtin(:non_neg_integer)
  defp do_mul(builtin(:pos_integer),     builtin(:pos_integer)),     do: builtin(:pos_integer)
  defp do_mul(builtin(:pos_integer),     builtin(:neg_integer)),     do: builtin(:neg_integer)
  defp do_mul(builtin(:neg_integer),     builtin(:non_neg_integer)), do: Type.union(builtin(:neg_integer), 0)
  defp do_mul(builtin(:neg_integer),     builtin(:pos_integer)),     do: builtin(:neg_integer)
  defp do_mul(builtin(:neg_integer),     builtin(:neg_integer)),     do: builtin(:pos_integer)
  defp do_mul(builtin(:integer),         builtin(:integer)),         do: builtin(:integer)
  defp do_mul(_,                         builtin(:float)),           do: builtin(:float)
  defp do_mul(builtin(:float),           _),                         do: builtin(:float)
  defp do_mul(t, builtin(:integer)) when t in @all_int_types,        do: builtin(:integer)
  defp do_mul(builtin(:integer), t) when t in @all_int_types,        do: builtin(:integer)

  opcode {:gc_bif, :*, _, _, [left, right], to} do
    forward(state, _meta, ...) do
      cond do
        # TODO: make this a guard.
        not is_defined(state, left) ->
          {:backprop, Enum.map(@int_types ++ @num_types, &put_reg(state, left, &1))}
        not is_defined(state, right) and fetch_type(state, left) in @int_types ->
          {:backprop, Enum.map(@int_types, &put_reg(state, right, &1))}
        not is_defined(state, right) and fetch_type(state, left) == builtin(:float) ->
          {:backprop, [put_reg(state, right, builtin(:float)), put_reg(state, right, builtin(:integer))]}
        not is_defined(state, right) and fetch_type(state, left) == builtin(:integer) ->
          {:backprop, [put_reg(state, right, builtin(:float))]}
        true ->
          ltype = fetch_type(state, left)
          rtype = fetch_type(state, right)
          res = do_mul(ltype, rtype)
          {:ok, put_reg(state, to, res)}
      end
    end

    # a temporary lie.
    backprop :terminal
  end
end
