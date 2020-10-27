defmodule Type.Inference.Opcodes.Calls do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  # MOVE SEMANTICS

  opcode {:call_ext_only, _arity, {:extfunc, _mod, _fun, _params}}, :noop
  #opcode {:call_ext_only, _arity, {:extfunc, _mod, _fun, _params}}, :unimplemented

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
