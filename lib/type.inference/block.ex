defmodule Type.Inference.Block do
  @enforce_keys [:needs, :makes]
  defstruct @enforce_keys

  @type t :: [%__MODULE__{
    needs: %{optional(integer) => Type.t},
    makes: %{optional(integer) => Type.t}
  }]

  defdelegate parse(code), to: Type.Inference.Block.Parser
end

defmodule Type.Inference.Block.Parser do
  @enforce_keys [:code]

  alias Type.Inference.{Vm, Module}

  defstruct @enforce_keys ++ [
    stack: [],
    histories: [[%Vm{}]]
  ]

  @type history :: [Vm.t]

  @type t :: %__MODULE__{
    code: [Module.opcode],
    stack: [Module.opcode],
    histories: [history]
  }

  alias Type.Inference.Block

  # TODO: fix it so it's not Module.opcode

  @spec parse([Module.opcode]) :: Block.t
  def parse(code) do
    %__MODULE__{code: code}
    |> do_analyze
    |> release
  end

  @spec release(t) :: Block.t
  def release(%{histories: histories}) do
    histories
    |> List.last  # get the params out
    |> Enum.zip(List.first(histories))
    |> Enum.map(fn {params, return} ->
      %Block{needs: params, makes: return}
    end)
  end

  def do_analyze(state, module \\ Type.Inference.Opcodes)
  def do_analyze(state = %{code: []}, _), do: state
  def do_analyze(state, module) do
    state
    |> do_forward(module)
    |> do_analyze(module)
  end

  # TODO: make check invariants on do_forward

  def do_forward(state, module \\ Type.Inference.Opcodes)
  def do_forward(state = %{code: [instr | _]}, module) do
    # apply the forward operation on the shard.

    new_histories = Enum.flat_map(state.histories,
      fn history = [latest | earlier] ->
        case module.forward(instr, latest) do
          {:ok, new_vm} -> [[new_vm | history]]
          {:backprop, replacement_vms} ->
            do_all_backprop(state, replacement_vms, earlier, module)
          :no_return -> []
        end
      end)

    %{state |
      code: tl(state.code),
      stack: [hd(state.code) | state.stack],
      histories: new_histories}
  end


  @spec do_all_backprop(t, [Vm.t], history, module) :: [history]
  defp do_all_backprop(state, replacement_vms, history, module) do
    Enum.flat_map(replacement_vms, fn vm ->
      # cut off all unprocessed code so we can return here.
      %{state |
        code: [hd(state.code)],
        stack: state.stack,
        histories: [[vm | history]]
      }
      |> do_backprop(module)
      |> Map.get(:histories)
    end)
  end


  def do_backprop(state, module \\ Type.Inference.Opcodes)
  @spec do_backprop(any, any) :: none
  def do_backprop(state = %{stack: []}, module) do
    # if we've run out of stack, then run the forward propagation
    do_analyze(state, module)
  end
  def do_backprop(state, module) do
    raise "no backprop yet"
  end

  ###############################################################
  ## TOOLS

  def advance(state, shards) do
    %{state |
      code: tl(state.code),
      shards: [shards | state.shards],
      stack: [hd(state.code) | state.stack]}
  end
end
