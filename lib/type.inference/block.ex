defmodule Type.Inference.Block do
  @enforce_keys [:needs, :makes]
  defstruct @enforce_keys

  @type t :: [%__MODULE__{
    needs: %{optional(integer) => Type.t},
    makes: Type.t
  }]

  defdelegate parse(code, module), to: Type.Inference.Block.Parser

  import Type

  @spec to_function(t) :: Type.t
  def to_function(blocks) do
    blocks
    |> Enum.map(fn block ->
      %Type.Function{
        params: get_params(block),
        return: block.makes,
        inferred: true
      }
    end)
    |> Enum.into(%Type.Union{})
  end

  defp get_params(%{needs: needs}) when needs == %{}, do: []
  defp get_params(block) do
    max_key = block.needs
    |> Map.keys
    |> Enum.max

    for idx <- 0..max_key do
      if type = block.needs[idx], do: type, else: builtin(:any)
    end
  end
end

defmodule Type.Inference.Block.Parser do
  @enforce_keys [:code, :histories, :meta]

  alias Type.Inference.{Vm, Module}

  defstruct @enforce_keys ++ [
    stack: []
  ]

  @type history :: [Vm.t]
  @type metadata :: %{
    required(:module) => module,
    optional(:fa) => {atom, arity}
  }

  @type t :: %__MODULE__{
    code: [Module.opcode],
    stack: [Module.opcode],
    histories: [history],
    meta: metadata
  }

  alias Type.Inference.Block

  def new(code, meta \\ []) do
    metadata = meta
    |> Enum.into(%{})
    |> Map.put_new(:module, nil)

    regs = meta[:preload] || %{}

    new(code, metadata, regs)
  end
  def new(code, meta, regs) do
    %__MODULE__{
      code: code,
      meta: meta,
      histories: [[%Vm{module: meta.module, xreg: regs}]]}
  end

  @spec parse([Module.opcode], keyword | map) :: Block.t
  def parse(code, metadata \\ []) do
    code
    |> new(metadata)
    |> do_analyze
    |> release
  end

  @spec release(t) :: Block.t
  def release(%{histories: histories}) do
    Enum.map(histories,
      &%Block{needs: List.last(&1).xreg, makes: List.first(&1).xreg[0]})
  end

  def do_analyze(state, module \\ Type.Inference.Opcodes)
  def do_analyze(state = %{code: []}, _), do: state
  def do_analyze(state, module) do
    state
    |> debug_print
    |> do_forward(module)
    |> do_analyze(module)
  end

  if Mix.env != :prod do
    defp debug_print(state = %{meta: meta}) do
      if meta[:fa] == Process.get(:fa) do
        state |> IO.inspect(label: "105")
      else
        state
      end
    end
  else
    defp debug_print(x), do: x
  end

  # TODO: make check invariants on do_forward

  def do_forward(state, opcode_module \\ Type.Inference.Opcodes)
  def do_forward(state = %{code: [instr | _]}, opcode_module) do
    # apply the forward operation on the shard.

    new_histories = Enum.flat_map(state.histories,
      fn history = [latest | earlier] ->
        case opcode_module.forward(instr, latest) do
          {:ok, new_vm} -> [[new_vm | history]]
          {:backprop, replacement_vms} ->
            do_all_backprop(state, replacement_vms, earlier, opcode_module)
          :no_return -> []
        end
      end)

    advance(state, new_histories)
  end

  @spec do_all_backprop(t, [Vm.t], history, module) :: [history]
  defp do_all_backprop(state, replacement_vms, history, opcode_module) do
    Enum.flat_map(replacement_vms, fn vm ->
      # cut off all unprocessed code so we can return here.
      %{state |
        code: [hd(state.code)],
        stack: state.stack,
        histories: [[vm | history]]
      }
      |> do_backprop(opcode_module)
      |> Map.get(:histories)
    end)
  end

  def do_backprop(state, module \\ Type.Inference.Opcodes)
  def do_backprop(state = %{stack: []}, opcode_module) do
    # if we've run out of stack, then run the forward propagation
    do_analyze(state, opcode_module)
  end
  def do_backprop(state = %{stack: [opcode | _]}, opcode_module) do
    new_histories = state.histories
    |> Enum.flat_map(fn [latest, _to_replace | earlier] ->
      case opcode_module.backprop(opcode, latest) do
        {:ok, new_starting_points} ->
          Enum.map(new_starting_points, &[&1 | earlier])
      end
    end)
    rollback(state, new_histories)
  end

  ################### =############################################
  ## TOOLS

  defp advance(state, new_histories) do
    %{state |
      code: tl(state.code),
      stack: [hd(state.code) | state.stack],
      histories: new_histories}
  end

  defp rollback(state, new_histories) do
    %{state |
      code: [hd(state.stack) | state.code],
      stack: tl(state.stack),
      histories: new_histories
    }
  end
end
