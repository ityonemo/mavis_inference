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

    backprop :unimplemented
  end

  # TODO: make this not be as crazy
  @int_types [builtin(:pos_integer), 0, builtin(:neg_integer)]
  @num_types [builtin(:float), builtin(:integer)]
  @add_result %{
    {builtin(:pos_integer), builtin(:pos_integer)} => builtin(:pos_integer),
    {builtin(:pos_integer), 0}                     => builtin(:pos_integer),
    {builtin(:pos_integer), builtin(:neg_integer)} => builtin(:integer),
    {0,                     builtin(:pos_integer)} => builtin(:pos_integer),
    {0,                     0}                     => 0,
    {0,                     builtin(:neg_integer)} => builtin(:neg_integer),
    {builtin(:neg_integer), builtin(:pos_integer)} => builtin(:integer),
    {builtin(:neg_integer), 0}                     => builtin(:neg_integer),
    {builtin(:neg_integer), builtin(:neg_integer)} => builtin(:neg_integer),
    {builtin(:integer),     builtin(:float)}       => builtin(:float),
    {builtin(:float),       builtin(:integer)}     => builtin(:float),
    {builtin(:float),       builtin(:float)}       => builtin(:float)}

  opcode {:gc_bif, :+, _, 2, [x: left, x: right], {:x, to}} do
    forward(state, ...) do
      cond do
        # TODO: make this a guard.
        not is_map_key(state.xreg, left) ->
          {:backprop, Enum.map(@int_types ++ @num_types, &put_reg(state, left, &1))}
        not is_map_key(state.xreg, right) and get_reg(state, left) in @int_types ->
          {:backprop, Enum.map(@int_types, &put_reg(state, right, &1))}
        not is_map_key(state.xreg, right) and get_reg(state, left) == builtin(:float) ->
          {:backprop, [put_reg(state, right, builtin(:float)), put_reg(state, right, builtin(:integer))]}
        not is_map_key(state.xreg, right) and get_reg(state, left) == builtin(:integer) ->
          {:backprop, [put_reg(state, right, builtin(:float))]}
        true ->
          ltype = get_reg(state, left)
          rtype = get_reg(state, right)
          res = @add_result[{ltype, rtype}]
          {:ok, put_reg(state, to, res)}
      end
    end

    # a temporary lie.
    backprop :terminal
  end

  opcode {:select_val, {:x, _from}, {:f, _fail}, {:list, _list}}, :noop
  #opcode {:select_val, {:x, _from}, {:f, _fail}, {:list, _list}}, :unimplemented

  opcode {:call_ext_only, _arity, {:extfunc, _mod, _fun, _params}}, :noop
  #opcode {:call_ext_only, _arity, {:extfunc, _mod, _fun, _params}}, :unimplemented

  opcode {:make_fun2, {module, fun, arity}, _, _, _} do
    # best guess:
    # ignore the last three terms.  Drops the mfa into register x0 always.
    forward(state = %{module: module}, ...) do
      return = fun
      |> ParallelParser.obtain_call(arity)
      |> Type.Inference.Block.to_function

      {:ok, put_reg(state, 0, return)}
    end

    forward :unimplemented
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

  opcode {:line, _}, :noop

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
end
