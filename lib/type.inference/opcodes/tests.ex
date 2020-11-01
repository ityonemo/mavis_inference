defmodule Type.Inference.Opcodes.Tests do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  @opdoc """
  takes the value in register `from` and checks if it's nil.  If it's nil, then proceed
  to the next opcode.  If it's not, then jump to block label `fail`
  """
  opcode {:test, :is_nil, {:f, fail}, [x: from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_map_key(state.x, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, nil) | jump_needs]}
        state.x[from] == nil ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, 0, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  # TODO: put this into mavis.
  defguard is_singleton(value) when is_atom(value) or is_integer(value)

  opcode {:test, :is_eq_exact, {:f, fail}, [x: left, x: right]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_map_key(state.x, 0) ->
          {:backprop, [put_reg(state, 0, builtin(:any))]}
        ! is_map_key(state.x, 1) ->
          {:backprop, [put_reg(state, 1, builtin(:any))]}
        is_singleton(get_reg(state, left)) and get_reg(state, left) == get_reg(state, right) ->
          {:ok, state}
        Type.intersection(get_reg(state, left), get_reg(state, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(state, 0, jump_res.makes)}
        true ->
          {:ok, [state, freeze: put_reg(state, 0, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

end
