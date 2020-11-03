defmodule Type.Inference.Opcodes.Bifs do

  import Type, only: :macros

  use Type.Inference.Macros

  opcode {:bif, :self, :nofail, [], to} do
    forward(state, meta, ...) do
      {:ok, put_reg(state, to, builtin(:pid))}
    end

    backprop :terminal
  end

  opcode {:bif, :map_get, fail, [map, key], dest} do
    forward(state, meta, ...) do
      cond do
        (not is_defined(state, map)) and (not is_defined(state, key)) ->
          any_map = %Type.Map{optional: %{builtin(:any) => builtin(:any)}}
          {:backprop, [put_reg(state, map, any_map)]}

        not is_defined(state, map) ->
          key_type = fetch_type(state, key)
          map_type = %Type.Map{optional: %{key_type => builtin(:any)}}
          {:backprop, [put_reg(state, map, map_type)]}

        not is_defined(state, key) ->
          map_type = fetch_type(state, map)
          key_type = Type.Map.preimage(map_type)
          {:backprop, [put_reg(state, key, key_type)]}

        true ->
          key_type = fetch_type(state, key)
          map_type = fetch_type(state, map)
          res_type = Type.Map.apply(map_type, key_type)
          {:ok, put_reg(state, dest, res_type)}
      end
    end

    backprop :terminal
  end

  opcode {:bif, :>, _fail, [left, right], dest} do
    forward(state, _meta, ...) do
      cond do
        not is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        not is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        true ->
          {:ok, put_reg(state, dest, builtin(:boolean))}
      end
    end

    backprop :terminal
  end

end
