defmodule Type.Inference.Opcodes.Calls do

  use Type.Inference.Opcodes

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block

  # todo: move this to a general tool in opcodes
  @spec collect_makes(Block.t) :: Type.t
  defp collect_makes(block) do
    block
    |> Enum.map(&(&1.makes))
    |> Enum.into(%Type.Union{})
  end

  # MOVE SEMANTICS
  opcode {:call_ext, _arity1, {:extfunc, mod, fun, arity}} do
    forward(regs, _meta, ...) do
      makes_type = {mod, fun, arity}
      |> BlockCache.depend_on
      |> collect_makes

      {:ok, put_reg(regs, {:x, 0}, makes_type)}
    end

    backprop :terminal
  end

  # disables _module_info and __info__.  Temporary only.
  opcode {:call_ext_only, _, {:extfunc, :erlang, :get_module_info, _}} do
    forward(regs, _meta, ...) do
      IO.warn("incorrect implementation of get_module_info trap")
      {:ok, regs}
    end

    backprop :terminal
  end

  opcode {:call_ext_only, _arity1, {:extfunc, mod, fun, arity}} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
      raise "unimplemented"
    end

    backprop :terminal
  end

  opcode {:call_ext_last, _arity1, {:extfunc, mod, fun, arity}, _} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
      raise "unimplemented"
    end

    backprop :terminal
  end

  opcode {:call, _arity1, {mod, fun, arity}} do
    forward(_state, _meta, ...) do
      BlockCache.depend_on({mod, fun, arity})
      raise "unimplemented"
    end

    backprop :terminal
  end

  opcode {:call_only, _arity1, {mod, fun, arity}} do
    forward(state, _meta, ...) do
      # TODO: allow this to take alternate specs
      [lookup] = BlockCache.depend_on({mod, fun, arity})

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
      raise "unimplemented"
    end

    backprop :terminal
  end

  opcode {:call_fun, _arity} do
    forward :unimplemented
    backprop :terminal
  end
end
