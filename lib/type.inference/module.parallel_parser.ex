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
      {fun, arity} = fun_for(entry_points, label)
      {label, Task.start_link(fn -> child(label, fun, arity, code) end)}
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
      receive do {:done, ^label, _fun, _arity, type} -> {label, type} end
    end)
    |> Enum.into(%{})
  end

  defp child(label, fun, arity, code) do
    init = receive do {:init, init} -> init end

    # DO SOMETHING WITH CODE
    block_lookup = Block.parse(code)

    [init.parent | Map.values(init.parsers)]
    |> Enum.map(&send_lookup(&1, label, fun, arity, block_lookup))

  rescue
    e in Type.UnknownOpcodeError ->
      reraise %{e | code_block: code}, __STACKTRACE__
  end

  defp fun_for(entry_points, label) do
    entry_points
    |> Enum.find_value(fn
      {fa, ^label} -> fa
      _ -> false
    end)
    |> Kernel.||({nil, nil})
  end

  @spec obtain_label(:beam_lib.label) :: Block.t

  def obtain_label(label) do
    receive do
      {:done, ^label, _fun, _arity, label_io} -> label_io
    end
  end

  def obtain_call(fun, arity) do
    receive do
      {:done, _label, ^fun, ^arity, label_io} -> label_io
    end
  end

  @spec send_lookup(pid, :beam_file.label, atom | nil, arity | nil, Block.t) :: term
  def send_lookup(who, label, fun, arity, block_lookup) do
    send(who, {:done, label, fun, arity, block_lookup})
  end

end
