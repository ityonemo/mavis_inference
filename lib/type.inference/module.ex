defmodule Type.Inference.Module do
  @doc """
  struct and operations for analyzing modules.
  """

  defstruct [
    label_blocks: %{},
    entry_points: %{}
  ]

  @type label :: pos_integer()

  @type label_blocks :: %{optional(label) => Type.t}
  @type entry_points :: %{optional({atom, arity}) => label}

  @type t :: %__MODULE__{
    label_blocks: label_blocks,
    entry_points: entry_points
  }

  alias Type.Inference.ParallelEngine

  @spec from_binary(binary) :: t
  def from_binary(binary) do

    {:beam_file, module, exports, _version, _meta, funs} = :beam_disasm.file(binary)

    entry_points = exports
    |> Enum.map(&export_to_ep_kv/1)
    |> Enum.into(%{})

    label_blocks = funs
    |> Enum.flat_map(fn fun_block ->
      fun_block
      |> strip_block
      |> opcodes_to_label_blocks(nil, [], [])
    end)
    |> Enum.into(%{})
    |> ParallelEngine.parse(module, entry_points)

    %__MODULE__{
      entry_points: entry_points,
      label_blocks: label_blocks
    }
  end

  defp export_to_ep_kv({export, arity, ep}), do: {{export, arity}, ep}

  defp strip_block({:function, _name, _arity, _entrypoint, list}), do: list

  @opaque opcode :: tuple

  @spec opcodes_to_label_blocks(
    block :: [opcode],
    label :: nil | label,
    this_block :: [opcode],
    all_blocks :: [{label, [opcode]}]) :: [{label, [opcode]}]

  defp opcodes_to_label_blocks([], nil, _, _), do: raise "unreachable"
  defp opcodes_to_label_blocks([], label, this_block, all_blocks) do
    [{label, Enum.reverse(this_block)} | all_blocks]
  end
  defp opcodes_to_label_blocks([{:label, label} | rest], nil, _, all_blocks) do
    opcodes_to_label_blocks(rest, label, [], all_blocks)
  end
  defp opcodes_to_label_blocks([{:label, new_label} | rest],
                               label,
                               this_block,
                               all_blocks) do
    opcodes_to_label_blocks(rest, new_label, [], [{label, Enum.reverse(this_block)} | all_blocks])
  end
  defp opcodes_to_label_blocks([head | rest], nil, this_block, all_blocks) do
    opcodes_to_label_blocks(rest, nil, [head | this_block], all_blocks)
  end
  defp opcodes_to_label_blocks([head | rest], label, this_block, all_blocks) do
    opcodes_to_label_blocks(rest, label, [head | this_block], all_blocks)
  end
end
