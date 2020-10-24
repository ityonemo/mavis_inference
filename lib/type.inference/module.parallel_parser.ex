defmodule Type.Inference.Module.ParallelParser do

  @enforce_keys [:parsers, :parent, :module, :entry_points]
  defstruct @enforce_keys

  alias Type.Inference.{Block, Module}

  # stateful information for solving tasks.  This will be sent
  # via message to the task.
  @type t :: %__MODULE__{
    parsers: [pid],
    parent: pid,
    module: module,
    entry_points: Module.entry_points
  }

  @spec parse(Module.block_lookup, module, Module.entry_points) ::
    %{optional(:beam_lib.label) => Type.t}
  def parse(block_lookup, module, entry_points) do
    # spin up a bunch of parsers in parallel
    parsers = block_lookup
    |> Enum.map(fn {label, code} ->
      {label, Task.start_link(fn -> child(label, code) end)}
    end)
    |> Enum.map(fn {label, {:ok, pid}} -> {label, pid} end)
    |> Enum.into(%{})

    # send out the common intitialization data to all of the child
    # parsers
    parsers
    |> Map.values
    |> Enum.map(&send(&1, {:init, %__MODULE__{
      parsers: parsers,
      parent: self(),
      module: module,
      entry_points: entry_points
    }}))

    # gather the results as constructed in
    parsers
    |> Map.keys
    |> Enum.map(fn label ->
      receive do {:done, ^label, type} -> {label, type} end
    end)
    |> Enum.into(%{})
  end

  defp child(label, code) do
    init = receive do {:init, init} -> init end

    # DO SOMETHING WITH CODE
    label_options = Block.parse(code)

    [init.parent | Map.values(init.parsers)]
    |> Enum.map(&send(&1, {:done, label, label_options}))

  rescue
    e in Type.UnknownOpcodeError ->
      reraise %{e | code_block: code}, __STACKTRACE__
  end

  @spec obtain_label(:beam_lib.label) :: Block.t

  def obtain_label(label) do
    receive do
      {:done, ^label, label_io} -> label_io
    end
  end

end
