defmodule Type.Inference.Module do
  @doc """
  struct and operations for analyzing modules.
  """

  @enforce_keys [:code]
  defstruct @enforce_keys ++ [
    block_lookup: %{},
    entry_points: %{},
  ]

  alias Type.Inference.Block

  @type block_lookup :: %{optional(:beam_lib.label) => Block.t}
  @type entry_points :: %{optional({atom, arity}) => :beam_lib.label}
  @opaque opcode :: tuple | :return

  @type t :: %__MODULE__{
    block_lookup: block_lookup,
    entry_points: entry_points,
    code: [opcode]
  }

  import Record
  defrecord :beam_file, Record.extract(:beam_file, from_lib: "compiler/src/beam_disasm.hrl")

  alias Type.Inference.Module.ParallelParser

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

        raw_opcodes = Enum.map(code, &strip_function_header/1)

        block_lookup = raw_opcodes
        |> Enum.flat_map(&opcodes_to_label_blocks(&1, nil, [], []))
        |> Enum.into(%{})
        |> ParallelParser.parse(module, entry_points)

        {:ok, %__MODULE__{
          entry_points: entry_points,
          block_lookup: block_lookup,
          code: raw_opcodes
        }}
      _ ->
        # TODO: make this not silly.
        {:error, "unable to disassemble"}
    end
  end

  defp strip_function_header({:function, _name, _arity, _entrypoint, list}), do: list

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
