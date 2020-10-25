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

  import Type

  ## API implementation
  @info_parts [:module, :name, :arity, :env]
  def infer(lambda) when is_function(lambda) do
    [module, fun, arity, _env] = lambda
    |> :erlang.fun_info
    |> Keyword.take(@info_parts)
    |> Keyword.values()

    case infer({module, fun, arity}) do
      f = {:ok, _} -> f
      :unknown -> {:ok, %Type.Function{
        params: any_for(arity),
        return: builtin(:any)
      }}
    end
  end
  def infer({module, fun, arity}) do
    fa = {fun, arity}
    with {^module, binary, _filepath} <- :code.get_object_code(module),
         {:ok, mod_struct} <- Type.Inference.Module.from_binary(binary),
         %{^fa => label} <- mod_struct.entry_points,
         %{^label => types} <- mod_struct.block_lookup do
      Type.Inference.Module.code(mod_struct, fun, arity) |> IO.inspect(label: "44")
      {:ok, Type.Inference.Block.to_function(types)}
    else
      _ -> :unknown
    end
  end

  def any_for(0), do: []
  def any_for(arity) do
    for _ <- 1..arity, do: builtin(:any)
  end
end
