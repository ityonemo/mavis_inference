
defmodule Type.Inference.Block.Parser.Api do
  @callback parse([Module.opcode], keyword) :: Block.t
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
    optional(:fa) => {atom, arity},
    optional(:log) => boolean
  }

  @type t :: %__MODULE__{
    code: [Module.opcode],
    stack: [Module.opcode],
    histories: [history],
    meta: metadata
  }

  alias Type.Inference.Block

  @spec new([Type.Inference.opcode], keyword | map) :: t
  def new(code, meta \\ []) do
    metadata = meta
    |> Enum.into(%{})
    |> Map.put_new(:module, nil)

    regs = meta[:preload] || %{}

    new(code, metadata, regs)
  end
  @spec new([any], map, any) :: Type.Inference.Block.Parser.t()
  def new(code, meta, regs) do
    %__MODULE__{
      code: code,
      meta: Map.put(meta, :length, length(code)),
      histories: [[%Registers{x: regs}]]}
  end

  @behaviour Type.Inference.Block.Parser.Api
  @impl true
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
    Type.Inference.Opcodes.Bifs,
    Type.Inference.Opcodes.Calls,
    Type.Inference.Opcodes.GcBifs,
    Type.Inference.Opcodes.Gets,
    Type.Inference.Opcodes.MakeFun,
    Type.Inference.Opcodes.Misc,
    Type.Inference.Opcodes.Move,
    Type.Inference.Opcodes.Puts,
    Type.Inference.Opcodes.Tests,
    Type.Inference.Opcodes.Terminal]

  @spec do_analyze(t, op_module) :: t
  def do_analyze(state, opcode_modules \\ nil)
  def do_analyze(state = %{code: []}, _), do: state
  def do_analyze(state, opcode_modules!) do
    opcode_modules! = opcode_modules! || @default_opcode_modules

    state
    |> do_forward(opcode_modules!)
    |> log_forward
    |> do_analyze(opcode_modules!)
  end

  @spec do_forward(t, op_module) :: t
  def do_forward(state, opcode_modules \\ nil)
  def do_forward(state = %{code: [opcode | _]}, opcode_modules!) do
    opcode_modules! = opcode_modules! || @default_opcode_modules

    new_histories = Enum.flat_map(state.histories,
      fn history = [latest | earlier] ->
        opcode
        |> reduce_forward(latest, state.meta, opcode_modules!)
        |> validate_forward(opcode)  # prevents stupid mistakes
        |> case do
          {:ok, new_regs} -> prep_ok(new_regs, length(state.stack), history)
          {:backprop, replacement_regs} ->
            do_all_backprop(state,
                            replacement_regs,
                            earlier,
                            opcode_modules!)
          :noop -> [[latest | history]]
          :unimplemented ->
            IO.warn("forward mode for the opcode #{inspect opcode} is not implemented yet.", [])
            [[latest | history]]
          :no_return -> []
          :unknown ->
            raise Type.UnknownOpcodeError, opcode: opcode
        end
      end)

    advance(state, new_histories)
  end

  defp prep_ok(new_regs, location, history) when is_list(new_regs) do
    Enum.map(new_regs, fn
      {:freeze, regs} -> [%{regs | freeze: location} | history]
      regs -> [regs | history]
    end)
  end
  defp prep_ok(new_regs, location, history), do: prep_ok([new_regs], location, history)

  @spec reduce_forward(term, Registers.t, map, op_module) ::
    {:ok, Registers.t} |
    {:ok, [Registers.t | {:freeze, Registers.t}]} |
    {:backprop, [Registers.t]} |
    :noop | :unimplemented | :no_return | :unknown

  # ignore frozen register histories.
  defp reduce_forward(_instr, latest = %{freeze: freeze}, _meta, _mods)
    when is_integer(freeze), do: {:ok, latest}
  defp reduce_forward(instr, latest, meta, opcode_modules) do
    opcode_modules
    |> List.wrap
    |> Enum.reduce(:unknown, fn
      module, :unknown ->
        module.forward(instr, latest, meta)
      _, result -> result
    end)
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
    |> Enum.flat_map(fn [out_regs, in_regs | earlier] ->
      # take the length of remaining items in the history, to figure out
      # whether or not we need to un-freeze this history
      stack_len = length(earlier)

      opcode
      |> reduce_backprop({out_regs, in_regs}, state.meta, stack_len, opcode_modules)
      |> validate_backprop(opcode)  # prevents stupid mistakes
      |> case do
        {:ok, new_starting_points} ->
          new_starting_points
          |> List.wrap
          |> Enum.map(&[&1 | earlier])
        :noop ->
          [[in_regs | earlier]]
        :unimplemented ->
          IO.warn("backprop mode for the opcode #{inspect opcode} is not implemented yet.", [])
          [[in_regs | earlier]]
        :no_return -> []
        :unknown ->
          raise Type.UnknownOpcodeError, opcode: opcode
      end
    end)
    # continue to backprop until we run out of stack.
    state
    |> rollback(new_histories)
    |> log_backprop
    |> do_backprop(opcode_modules)
  end

  @spec reduce_backprop(term, {Registers.t, Registers.t}, map, non_neg_integer, op_module) ::
    {:ok, [Registers.t]} | {:ok, Registers.t} |
    :noop | :unimplemented | :no_return | :unknown
  defp reduce_backprop(_, {%{freeze: freeze}, in_regs}, _, stack_len, _)
      when is_integer(freeze) and freeze != stack_len do
    {:ok, in_regs}
  end
  defp reduce_backprop(opcode, latest, meta, _stack_len, opcode_modules) do
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

  ################################################################
  ## TESTING CONVENIENCES

  if Mix.env() == :test do

    @shortforms ~w(noop unimplemented no_return unknown)a

    defp validate_forward(fwd = {:ok, %Registers{}}, _), do: fwd
    defp validate_forward(fwd = {:ok, [%Registers{} | _]}, _), do: fwd
    defp validate_forward(fwd = {:ok, [{:freeze, %Registers{}} | _]}, _), do: fwd
    defp validate_forward(bck = {:backprop, [%Registers{} | _]}, _), do: bck
    defp validate_forward(bck = {:backprop, []}, _), do: bck
    defp validate_forward(short, _) when short in @shortforms, do: short
    defp validate_forward(invalid, opcode) do
      raise "invalid forward result #{inspect invalid} when processing opcode #{inspect opcode}"
    end

    defp validate_backprop(bck = {:ok, %Registers{}}, _), do: bck
    defp validate_backprop(bck = {:ok, []}, _), do: bck
    defp validate_backprop(bck = {:ok, [%Registers{} | _]}, _), do: bck
    defp validate_backprop(short, _) when short in @shortforms, do: short
    defp validate_backprop(bck, opcode) do
      raise "invalid backprop result #{inspect bck} when processing opcode #{inspect opcode}"
    end

    def log_forward(regs = %{meta: %{log: true}}) do
      IO.puts("forward pass result: #{inspect regs, structs: false}")
      regs
    end
    def log_forward(regs = %{meta: %{module: module, label: label}}) do
      case Application.get_env(:mavis_inference, :log) do
        :all ->
          IO.puts("forward pass result #{inspect regs, structs: false}")
        {^module, ^label} ->
          IO.puts("forward pass result #{inspect regs, structs: false}")
        _ -> :ok
      end

      regs
    end
    def log_forward(regs), do: regs

    def log_backprop({regs = %{meta: %{log: true}}, _}) do
      IO.puts("backprop pass result: #{inspect regs, structs: false}")
      regs
    end
    def log_backprop({regs = %{meta: %{module: module, label: label}}, _}) do
      case Application.get_env(:mavis_inference, :log) do
        :all ->
          IO.puts("backprop pass result #{inspect regs, structs: false}")
        {^module, ^label} ->
          IO.puts("forward pass result #{inspect regs, structs: false}")
        _ -> :ok
      end
      regs
    end
    def log_backprop(regs), do: regs

  else
    defp validate_forward(any, _), do: any
    defp validate_backprop(bck, _), do: bck

    defp log_forward(state), do: state
    defp log_backprop(state), do: state
  end
end
