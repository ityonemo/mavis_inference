defmodule Type.Inference.Opcodes.Terminal do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  opcode {:select_val, {:x, from}, {:f, _fail}, {:list, list}} do
    forward(state, _meta, ...) do
      # TODO: fix this so that it merges instead of
      # clobbering, for example if we have two String.t's coming
      # in with different jump registers.
      select_table = list
      |> Enum.chunk_every(2)
      |> Enum.map(fn [param, jump] ->
        {evaluate_param(param), evaluate_jump(jump)}
      end)
      |> Enum.into(%{})

      if is_map_key(state.x, from) do
        jump_reg = get_reg(state, from)

        result_type = ParallelParser.obtain_label(select_table[jump_reg])
        |> Enum.map(&(&1.makes))
        |> Type.union()

        {:ok, put_reg(state, 0, result_type)}
      else
        type_table = select_table
        |> Map.keys
        |> Enum.map(&put_reg(state, from, &1))

        {:backprop, type_table}
      end
    end

    backprop :terminal
  end

  # TODO: this is going to be more general over time.
  # Move this into a tools function that can be used my
  # multiple opcode modules.
  defp evaluate_param({:atom, atom}), do: atom
  defp evaluate_jump({:f, int}), do: int

  opcode :return do
    forward(state = %{x: %{0 => _type}}, _meta, ...) do
      {:ok, state}
    end
    forward(state = %{x: %{}}, _meta, ...) do
      {:backprop, [put_reg(state, 0, builtin(:any))]}
    end

    backprop :terminal
  end

  opcode {:line, _}, :noop

  opcode {:func_info, _, _, _} do
    forward(state, _meta, ...) do
      {:ok, put_reg(state, 0, builtin(:none))}
    end

    backprop :terminal
  end
end
