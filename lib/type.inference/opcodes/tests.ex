defmodule Type.Inference.Opcodes.Tests do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  @opdoc """
  takes the value in register `from` and checks if it's nil.  If it's nil, then proceed
  to the next opcode.  If it's not, then jump to block label `fail`
  """
  opcode {:test, :is_nil, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_reg(state.x, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, nil) | jump_needs]}
        state.x[from] == nil ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_nonempty_list, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        ! is_reg(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, %Type.List{nonempty: true, type: builtin(:any)}) | jump_needs]}
        match?(%Type.List{nonempty: true}, fetch_type(state, from)) ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  # TODO: put this into mavis.
  defguard is_singleton(value) when is_atom(value) or is_integer(value)

  opcode {:test, :is_eq_exact, {:f, fail}, [left, right]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_reg(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        ! is_reg(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        is_singleton(fetch_type(state, left)) and fetch_type(state, left) == fetch_type(state, right) ->
          {:ok, state}
        Type.intersection(fetch_type(state, left), fetch_type(state, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(state, left, jump_res.makes)}
        true ->
          {:ok, [state, freeze: put_reg(state, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

end
