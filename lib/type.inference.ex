defmodule Type.Inference do

  require Type.Inference.Macros
  import Type.Inference.Macros

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

    infer({module, fun, arity})
  end
  def infer({module, fun, arity}) do
    case :code.get_object_code(module) do
      {^module, binary, _filepath} ->
        {:beam_file, ^module, _funs_list, _vsn, _meta, functions} = :beam_disasm.file(binary)
        code = Enum.find(functions,
          fn
            {:function, ^fun, ^arity, _, _code} -> true
            _ -> false
          end)

        code || raise "fatal error; can't find function `#{fun}/#{arity}` in module #{inspect module}"

        infer(code)
      :error ->
        {:ok, %Type.Function{params: any_for(arity), return: builtin(:any), inferred: false}}
    end
  end
  def infer({:function, _name, arity, _index, code}) do
    Type.Inference.run(code, starting_map(arity))
  end

  defp any_for(arity) do
    fn -> builtin(:any) end
    |> Stream.repeatedly
    |> Enum.take(arity)
  end

  defp starting_map(0), do: %{}
  defp starting_map(arity) do
    0..(arity - 1)
    |> Enum.map(&{&1, builtin(:any)})
    |> Enum.into(%{})
  end

  #def run(code, starting_map, module \\ __MODULE__.Opcodes) do
  #  [end_states | rest] = %__MODULE__{code: code, regs: [[starting_map]]}
  #  |> do_analyze(module)
  #  |> Map.get(:regs)
#
  #  initial_registers = Map.keys(starting_map)
#
  #  type = rest
  #  |> List.last   # grab the initial registry states
  #  |> Enum.zip(end_states)
  #  |> Enum.map(fn {params, return} ->
#
  #    # we need to filter out "old" values since some values
  #    # could have been padded in by clobbering opcodes
  #    init_params = params
  #    |> Enum.filter(fn {k, _} -> k in initial_registers end)
  #    |> Enum.map(&elem(&1, 1))
#
  #    %Type.Function{params: init_params, return: return[0]}
  #  end)
  #  |> Enum.into(%Type.Union{})
#
  #  {:ok, type}
  #rescue
  #  e in Type.UnknownOpcodeError ->
  #    reraise %{e | code_block: code}, __STACKTRACE__
  #end

end
