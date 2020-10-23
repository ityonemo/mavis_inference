defmodule Type.Inference do

  @enforce_keys [:code, :regs]
  defstruct @enforce_keys ++ [
    stack: []
  ]

  @type opcode :: atom | tuple
  @type reg_state :: %{
    optional(integer) => Type.t,
    optional(:line) => non_neg_integer,
    optional(:warn) => any}

  @type state :: %__MODULE__{
    code:  [opcode],
    stack: [opcode],
    regs:  [[reg_state]]
  }

  ## API implementation
  @info_parts [:module, :name, :arity, :env]
  def infer(lambda) when is_function(lambda) do
    [module, fun, arity, _env] = lambda
    |> :erlang.fun_info
    |> Keyword.take(@info_parts)
    |> Keyword.values()

    infer({module, fun, arity})
  end
  def infer({module, fun, arity}) do
    case :code.get_object_code(module) do
      {^module, binary, _filepath} ->
        Type.Inference.Module.from_binary(binary)


      :error ->
        :unknown
    end
  end
end
