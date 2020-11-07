defmodule Type.Inference.Opcodes.Calls do

  use Type.Inference.Opcodes

  alias Type.Inference.Module.ParallelParser

  # MOVE SEMANTICS
  @operands [:module, :exports, :attributes, :compile, :native, :md5]

  opcode {:call_ext, _arity1, {:extfunc, mod, fun, arity}} do
    forward(_state, meta, ...) do
      if meta.module == mod do
        ParallelParser.obtain_call(fun, arity)
        |> IO.inspect(label: "15")
      else
        Type.Inference.BlockCache.request({mod, fun, arity})
        |> IO.inspect(label: "18")
      end
    end

    backprop :terminal
  end

  opcode {:call_ext_only, _arity1, {:extfunc, mod, fun, arity}} do
    forward(_state, meta, ...) do
      if meta.module == mod do
        ParallelParser.obtain_call(fun, arity)
        |> IO.inspect(label: "28")
      else
        Type.Inference.BlockCache.request({mod, fun, arity})
        |> IO.inspect(label: "32")
      end
    end

    backprop :terminal
  end

  opcode {:call_ext_last, _arity1, {:extfunc, mod, fun, arity}, _} do
    forward(_state, meta, ...) do
      if meta.module == mod do
        ParallelParser.obtain_call(fun, arity)
        |> IO.inspect(label: "43")
      else
        Type.Inference.BlockCache.request({mod, fun, arity})
        |> IO.inspect(label: "46")
      end
    end

    backprop :terminal
  end

  opcode {:call, _arity1, {mod, fun, arity}} do
    forward(_state, meta, ...) do
      if meta.module == mod do
        ParallelParser.obtain_call(fun, arity)
        |> IO.inspect(label: "57")
      else
        Type.Inference.BlockCache.request({mod, fun, arity})
        |> IO.inspect(label: "60")
      end
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
        {:ok, put_reg(state, {:x, 0}, lookup.makes)}
      else
        {:backprop, [merge_reg(state, lookup.needs)]}
      end
    end

    backprop :terminal
  end

  opcode {:call_last, _arity1, {mod, fun, arity}, _} do
    forward(_state, meta, ...) do
      if meta.module == mod do
        ParallelParser.obtain_call(fun, arity)
        |> IO.inspect(label: "57")
      else
        Type.Inference.BlockCache.request({mod, fun, arity})
        |> IO.inspect(label: "60")
      end
    end

    backprop :terminal
  end
end
