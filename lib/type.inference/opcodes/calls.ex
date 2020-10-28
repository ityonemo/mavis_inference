defmodule Type.Inference.Opcodes.Calls do

  use Type.Inference.Macros
  import Type

  alias Type.Inference.Module.ParallelParser

  # MOVE SEMANTICS

  @operands [:module, :exports, :attributes, :compile, :native, :md5]

  # THESE OPCODES ARE TEMPORARY.  Let's get just something working first.
  opcode {:call_ext_only, _arity, {:extfunc, :erlang, :get_module_info, 1}} do
    forward(state, _meta, ...) do
      if is_map_key(state.x, 0) do
        {:ok, put_reg(state, 0, builtin(:keyword))}
      else
        {:backprop, [put_reg(state, 0, builtin(:module))]}
      end
    end
    backprop :terminal
  end

  opcode {:call_ext_only, _arity, {:extfunc, :erlang, :get_module_info, 2}} do
    forward(state, _meta, ...) do
      cond do
        not is_map_key(state.x, 0) ->
          {:backprop, [put_reg(state, 0, builtin(:module))]}
        not is_map_key(state.x, 1) ->
          {:backprop, Enum.map(@operands, &put_reg(state, 1, &1))}
        true ->
          case state.x[1] do
            :module -> {:ok, put_reg(state, 0, builtin(:module))}
            :exports -> {:ok, put_reg(state, 0, builtin(:keyword))}
            :attributes -> {:ok, put_reg(state, 0, builtin(:keyword))}
            :compile -> {:ok, put_reg(state, 0, builtin(:keyword))}
            :native -> {:ok, put_reg(state, 0, builtin(:boolean))}
            :md5 -> {:ok, put_reg(state, 0, %Type.Bitstring{size: 16 * 8})}
            _ -> {:backprop, Enum.map(@operands, &put_reg(state, 1, &1))}
          end
      end
    end
    backprop :terminal
  end

  opcode {:call_ext_only, _arity, {:extfunc, _mod, _fun, _arity}}, :unimplemented

  opcode {:call_only, _arity1, {_this_module, function, arity}} do
    forward(state, _meta, ...) do
      # TODO: allow this to take alternate specs
      [lookup] = ParallelParser.obtain_call(function, arity)

      # make sure that all of the "needs" are taken care of.
      lookup.needs
      |> Map.keys
      |> Enum.all?(&(&1 in Map.keys(state.x)))
      |> if do
        {:ok, put_reg(state, 0, lookup.makes)}
      else
        {:backprop, [merge_reg(state, lookup.needs)]}
      end
    end

    backprop :terminal
  end
end
