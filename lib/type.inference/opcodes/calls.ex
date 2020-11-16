defmodule Type.Inference.Opcodes.Calls do

  use Type.Inference.Opcodes

  alias Type.Inference.Application.BlockCache

  # MOVE SEMANTICS
  @operands [:module, :exports, :attributes, :compile, :native, :md5]

  opcode {:call_ext, _arity1, {:extfunc, mod, fun, arity}} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
    end

    backprop :terminal
  end

  # disables _module_info.
  opcode {:call_ext_only, _, {:extfunc, :erlang, :get_module_info, _}} do
    forward(state, _meta, ...) do
      {:ok, state}
    end

    backprop :terminal
  end

  opcode {:call_ext_only, _arity1, {:extfunc, mod, fun, arity}} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
    end

    backprop :terminal
  end

  opcode {:call_ext_last, _arity1, {:extfunc, mod, fun, arity}, _} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
    end

    backprop :terminal
  end

  opcode {:call, _arity1, {mod, fun, arity}} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
    end

    backprop :terminal
  end

  opcode {:call_only, _arity1, {_this_module, function, arity}} do
    forward(state, _meta, ...) do
      # TODO: allow this to take alternate specs
      [lookup] = BlockCache.depend_on(function, arity)

      # make sure that all of the "needs" are taken care of.
      lookup.needs
      |> Map.keys
      |> Enum.all?(&(&1 in Map.keys(state.x)))
      |> if do
        {:ok, put_reg(state, {:x, 0}, lookup.makes)}
      else
        {:backprop, [merge_reg(state, lookup.needs)]}
      end
    end

    backprop :terminal
  end

  opcode {:call_last, _arity1, {mod, fun, arity}, _} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
    end

    backprop :terminal
  end

  opcode {:call_fun, _arity} do
    forward :unimplemented
    backprop :terminal
  end
end
