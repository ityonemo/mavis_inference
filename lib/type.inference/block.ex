defmodule Type.Inference.Block do
  @enforce_keys [:needs, :makes]
  defstruct @enforce_keys

  @type t :: [%__MODULE__{
    needs: %{optional(integer) => Type.t},
    makes: Type.t
  }]

  defdelegate parse(code, metadata \\ []), to: Type.Inference.Block.Parser

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

  @type op_module :: [module] | module

  alias Type.Inference.{Registers, Module}

  defstruct @enforce_keys ++ [
    stack: []
  ]

  @type history :: [Registers.t]
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
      meta: Map.put(meta, :length, length(code)),
      histories: [[%Registers{x: regs}]]}
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
      &%Block{needs: List.last(&1).x, makes: List.first(&1).x[0]})
  end

  @default_opcode_modules [
    Type.Inference.Opcodes.Calls,
    Type.Inference.Opcodes.GcBif,
    Type.Inference.Opcodes.MakeFun,
    Type.Inference.Opcodes.Misc,
    Type.Inference.Opcodes.Move,
    Type.Inference.Opcodes.Terminal]

  @spec do_analyze(t, op_module) :: t
  def do_analyze(state, opcode_modules \\ @default_opcode_modules)
  def do_analyze(state = %{code: []}, _), do: state
  def do_analyze(state, opcode_modules) do
    state
    |> do_forward(opcode_modules)
    |> do_analyze(opcode_modules)
  end

  @spec do_forward(t, op_module) :: t
  def do_forward(state, opcode_modules \\ @default_opcode_modules)
  def do_forward(state = %{code: [opcode | _]}, opcode_modules) do
    new_histories = Enum.flat_map(state.histories,
      fn history = [latest | earlier] ->
        opcode
        |> reduce_forward(latest, state.meta, opcode_modules)
        |> validate_forward  # prevents stupid mistakes
        |> case do
          {:ok, new_vm} -> [[new_vm | history]]
          {:backprop, replacement_vms} ->
            do_all_backprop(state,
                            replacement_vms,
                            earlier,
                            opcode_modules)
          :no_return -> []
          :unknown ->
            raise Type.UnknownOpcodeError, opcode: opcode
        end
      end)

    advance(state, new_histories)
  end

  @spec reduce_forward(term, Registers.t, map, op_module) :: {:ok, Registers.t} | {:backprop, [Registers.t]} | :no_return | :unknown
  defp reduce_forward(instr, latest, meta, opcode_modules) do
    opcode_modules
    |> List.wrap
    |> Enum.reduce(:unknown, fn
      module, :unknown ->
        module.forward(instr, latest, meta)
      _, result -> result
    end)
  end

  if Mix.env() == :test do
    defp validate_forward(fwd = {:ok, %Registers{}}), do: fwd
    defp validate_forward(bck = {:backprop, [%Registers{} | _]}), do: bck
    defp validate_forward(bck = {:backprop, []}), do: bck
    defp validate_forward(:no_return), do: :no_return
    defp validate_forward(:unknown), do: :unknown
    defp validate_forward(xxx) do
      raise "invalid forward propagation result #{inspect xxx}"
    end
  else
    defp validate_forward(any), do: any
  end

  @spec do_all_backprop(t, [Registers.t], history, [module]) :: [history]
  defp do_all_backprop(state, replacement_vms, history, opcode_modules) do
    Enum.flat_map(replacement_vms, fn vm ->
      # cut off all unprocessed code so we can return here.
      %{state |
          code: [hd(state.code)],
          stack: state.stack,
          histories: [[vm | history]]}
      |> do_backprop(opcode_modules)
      |> Map.get(:histories)
    end)
  end

  @spec do_backprop(t, op_module) :: t
  def do_backprop(state, opcode_modules \\ @default_opcode_modules)
  def do_backprop(state = %{stack: []}, opcode_modules) do
    # if we've run out of stack, then run the forward propagation
    do_analyze(state, opcode_modules)
  end
  def do_backprop(state = %{stack: [opcode | _]}, opcode_modules) do
    new_histories = state.histories
    |> Enum.flat_map(fn [latest, _to_replace | earlier] ->
      opcode
      |> reduce_backprop(latest, state.meta, opcode_modules)
      |> validate_backprop  # prevents stupid mistakes
      |> case do
        {:ok, new_starting_points} ->
          Enum.map(new_starting_points, &[&1 | earlier])
      end
    end)
    # continue to backprop until we run out of stack.
    state
    |> rollback(new_histories)
    |> do_backprop(opcode_modules)
  end

  if Mix.env() == :test do
    defp validate_backprop(bck = {:ok, []}), do: bck
    defp validate_backprop(bck = {:ok, [%Registers{} | _]}), do: bck
    defp validate_backprop(bck) do
      raise "invalid backprop result #{inspect bck}"
    end
  else
    defp validate_backprop(bck), do: bck
  end

  @spec reduce_backprop(term, Registers.t, map, op_module) :: {:ok, [Registers.t]}
  defp reduce_backprop(opcode, latest, meta, opcode_modules) do
    opcode_modules
    |> List.wrap
    |> Enum.reduce(:unknown, fn
      module, :unknown ->
        module.backprop(opcode, latest, meta)
      _, result -> result
    end)
  end

  ###############################################################
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
