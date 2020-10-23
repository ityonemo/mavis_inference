defmodule Type.Inference.Label do

  @enforce_keys [:code]

  alias Type.Inference.{Module, Vm}

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

  @spec parse([Module.opcode]) :: Type.t
  def parse(code) do
    %__MODULE__{code: code}
    |> do_analyze
    |> release
  end

  @spec release(t) :: Type.t
  def release(%{histories: histories}) do
    histories
    |> List.last  # get the params out
    |> Enum.zip(List.first(histories))
    |> Enum.map(fn {params, return} ->
      %Type.Function{
        params: Map.values(params.xreg),
        return: return.xreg[0]
      }
    end)
    |> Enum.into(%Type.Union{})
  end

  def do_analyze(state, module \\ Type.Inference.Opcodes)
  def do_analyze(state = %{code: []}, _), do: state
  def do_analyze(state, module) do
    state
    |> do_forward(module)
    |> do_analyze(module)
  end

  # TODO: make check invariants on do_forward

  import Type.Inference.Macros

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
    # performs backpropagation on the current state.
    # first, run the backpropagation and answer the question:
    # did we need to change any of the forward enties.
    #%{stack: [this | _], shards: [[latest], [prev] | _]} = state
#
    #case module.backprop(this, latest) do
    #  {:ok, ^prev} ->
    #    state
    #  {:ok, replacement} ->
    #    state
    #    |> pop_reg_replace([replacement])
    #    |> unshift
    #    |> do_backprop(module)
    #  {:error, _} ->
    #    %{state | shards: [[] | tl(state.regs)]}
    #end
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
