defmodule Type.Inference.Opcodes.Calls do

  use Type.Inference.Macros
  import Type

  alias Type.Inference.Module.ParallelParser

  # MOVE SEMANTICS
  @operands [:module, :exports, :attributes, :compile, :native, :md5]

  opcode {:call_ext_only, _arity1, {:extfunc, mod, fun, arity}} do
    forward(_state, _meta, ...) do
      Type.Inference.fetch_block(mod, fun, arity)
    end
    backprop :terminal
  end

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
