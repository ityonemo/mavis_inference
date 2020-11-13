defmodule Type.Inference.Application.ModuleAnalyzer do

  alias Type.Inference.Application.BlockAnalyzer
  alias Type.Inference.Application.Depends

  def run(module) do
    Task.Supervisor.start_child(Type.Inference.TaskSupervisor, fn ->
      task(module)
    end)
  end

  @spec task(module) :: :ok
  # preflight checks on the module contents to make sure that the system is in a
  # sane state to perform inference.
  defp task(module) do
    # Register ourselves with the module registry.
    with {:ok,  } <- Registry.register(Type.Inference.ModuleTracker, module, []),
         {:module, _} <- Code.ensure_loaded(module),
         {^module, binary, _filepath} <- :code.get_object_code(module) do

      infer(binary, module)
    else
      {:error, {:already_registered, _}} ->
        # do nothing if someone else is already working on this module
        :ok
      {:error, _} ->
        # when coming from
        raise "error loading module #{inspect module}"
      :error ->
        # happens when the module is in-memory
        raise "cannot run inference on an in-memory module"
    end
  end

  import Record
  defrecord :beam_file, Record.extract(:beam_file, from_lib: "compiler/src/beam_disasm.hrl")

  # TODO: set the correct return value for this.
  @spec infer(binary, module, block_inference_inj :: module) :: :ok
  def infer(binary, module, block_analyzer \\ BlockAnalyzer) do
    case :beam_disasm.file(binary) do
      beam_file(module: ^module, code: code) ->
        entry_points = code
        |> Enum.map(fn
          {:function, name, arity, entry_point, _code} ->
            {entry_point, {name, arity}}
        end)
        |> Enum.into(%{})

        raw_opcodes = Enum.map(code, &strip_function_header/1)

        raw_opcodes
        |> Enum.flat_map(&opcodes_to_label_blocks(&1, nil, [], []))
        |> Enum.map(fn {label, code} ->
          block_analyzer.run({module, entry_points[label], label, code})
          label
        end)
        |> Enum.each(&Depends.on({module, &1}))

      _ ->
        raise "unable to disassemble module #{module}"
    end
  end

  defp strip_function_header({:function, _name, _arity, _entrypoint, list}), do: list

  @typep opcode :: Type.Inference.opcode

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
