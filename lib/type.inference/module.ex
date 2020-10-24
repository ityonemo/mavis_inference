defmodule Type.Inference.Module do
  @doc """
  struct and operations for analyzing modules.
  """

  defstruct [
    label_blocks: %{},
    entry_points: %{}
  ]

  alias Type.Inference.Label

  @type label_blocks :: %{optional(:beam_lib.label) => Label.t}
  @type entry_points :: %{optional({atom, arity}) => :beam_lib.label}

  @type t :: %__MODULE__{
    label_blocks: label_blocks,
    entry_points: entry_points
  }

  import Record
  defrecord :beam_file, Record.extract(:beam_file, from_lib: "compiler/src/beam_disasm.hrl")

  alias Type.Inference.ParallelEngine

  @spec from_binary(binary) :: {:ok, t} | {:error, term}
  def from_binary(binary) do
    case :beam_disasm.file(binary) do
      beam_file(module: module, code: code) ->
        entry_points = code
        |> Enum.map(fn
          {:function, name, arity, entry_point, _code} ->
            {{name, arity}, entry_point}
        end)
        |> Enum.into(%{})

        label_blocks = code
        |> Enum.flat_map(fn fun_block ->
          fun_block
          |> strip_block
          |> opcodes_to_label_blocks(nil, [], [])
        end)
        |> Enum.into(%{})
        |> ParallelEngine.parse(module, entry_points)

        {:ok, %__MODULE__{
          entry_points: entry_points,
          label_blocks: label_blocks
        }}
      _ ->
        # TODO: make this not silly.
        {:error, "unable to disassemble"}
    end
  end

  defp export_to_ep_kv({export, arity, ep}), do: {{export, arity}, ep}

  defp strip_block({:function, _name, _arity, _entrypoint, list}), do: list

  @opaque opcode :: tuple | :return

  @spec opcodes_to_label_blocks(
    block :: [opcode],
    label :: nil | :beam_lib.label,
    this_block :: [opcode],
    all_blocks :: [{:beam_lib.label, [opcode]}]) :: [{:beam_lib.label, [opcode]}]

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
