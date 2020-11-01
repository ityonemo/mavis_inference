defmodule Type.Inference do
  @enforce_keys [:code, :regs]
  defstruct @enforce_keys ++ [
    stack: []
  ]

  @type opcode :: atom | tuple

  @type state :: %__MODULE__{
    code:  [opcode],
    stack: [opcode],
    regs:  [[Registers.t]]
  }

  import Type

  @behaviour Type.Inference.Api

  @impl true
  @spec infer(module, atom, arity) :: {:ok, Type.t} | {:error, any}
  def infer(module, fun, arity) do
    fa = {fun, arity}
    with {:module, _} <- Code.ensure_loaded(module),
         {^module, binary, _filepath} <- :code.get_object_code(module),
         {:ok, mod_struct} <- Type.Inference.Module.from_binary(binary),
         %{^fa => label} <- mod_struct.entry_points,
         %{^label => types} <- mod_struct.block_lookup do
      {:ok, Type.Inference.Block.to_function(types)}
    else
      :error ->
        # must tolerate in-memory modules
        :unknown
      error = {:error, _} -> error
    end
  end

  def fetch_block(module, fun, arity, inference_module! \\ __MODULE__) do
    inference_module! = Application.get_env(:mavis, :inference, inference_module!)
    case inference_module!.infer(module, fun, arity) do
      {:ok, spec} -> Type.Inference.Block.from_spec(spec)
      error -> error
    end
  end
end
