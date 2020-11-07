defmodule Type.Inference.Opcodes.Terminal do
  use Type.Inference.Opcodes

  alias Type.Inference.Module.ParallelParser

  opcode {:select_val, from, {:f, _fail}, {:list, list}} do
    forward(regs, _meta, ...) do
      # TODO: fix this so that it merges instead of
      # clobbering, for example if we have two String.t's coming
      # in with different jump registers.
      select_table = list
      |> Enum.chunk_every(2)
      |> Enum.map(fn [param, jump] ->
        {evaluate_param(param), evaluate_jump(jump)}
      end)
      |> Enum.into(%{})

      if is_defined(regs, from) do
        jump_reg = fetch_type(regs, from)

        result_type = ParallelParser.obtain_label(select_table[jump_reg])
        |> Enum.map(&(&1.makes))
        |> Type.union()

        {:ok, put_reg(regs, {:x, 0}, result_type)}
      else
        type_table = select_table
        |> Map.keys
        |> Enum.map(&put_reg(regs, from, &1))

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
    forward(regs = %{x: %{0 => _type}}, _meta, ...) do
      {:ok, regs}
    end
    forward(regs = %{x: %{}}, _meta, ...) do
      {:backprop, [put_reg(regs, {:x, 0}, builtin(:any))]}
    end

    backprop :terminal
  end

  opcode {:line, _}, :noop

  opcode {:func_info, _, _, _} do
    forward(regs, _meta, ...) do
      {:ok, put_reg(regs, {:x, 0}, builtin(:none))}
    end

    backprop :terminal
  end

  opcode {:jump, {:f, dest}} do
    forward(regs, _meta, ...) do
      [jump_blk] = ParallelParser.obtain_label(dest)

      if reg = Enum.find(Map.keys(jump_blk.needs), &(!is_defined(regs, {:x, &1}))) do
        {:backprop, [put_reg(regs, reg, jump_blk.needs[reg])]}
      else
        {:ok, put_reg(regs, {:x, 0}, jump_blk.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:wait, {:f, dest}} do
    forward(regs, _meta, ...) do
      [jump_blk] = ParallelParser.obtain_label(dest)

      if reg = Enum.find(Map.keys(jump_blk.needs), &(!is_defined(regs, {:x, &1}))) do
        {:backprop, [put_reg(regs, reg, jump_blk.needs[reg])]}
      else
        {:ok, put_reg(regs, {:x, 0}, jump_blk.makes)}
      end
    end

    backprop :terminal
  end
end
