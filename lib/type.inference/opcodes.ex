defmodule Type.Inference.Opcodes do

  @moduledoc """
  ## options:
  - debug_dump_code: if true then dumps the code at the end.
  """

  defmodule Operations do
    @enforce_keys ~w(type opcode_ast code_ast)a
    defstruct @enforce_keys ++ [reg_ast: nil, meta_ast: nil, guard_ast: nil]

    @type t :: %__MODULE__{
      type: :forward | :backprop,
      opcode_ast: Macro.t,
      code_ast: Macro.t | :noop | :unimplemented,
      reg_ast: Macro.t | nil,
      meta_ast: Macro.t | nil,
      guard_ast: Macro.t | nil,
    }

    @spec rebuild(nil | [t]) :: [Macro.t]
    def rebuild(nil), do: []
    def rebuild(op_list) do
      Enum.map(op_list, &to_ast/1)
    end

    @spec to_ast(t) :: Macro.t
    def to_ast(op = %{guard_ast: nil}) do
      quote do
        def unquote(op.type)(unquote(op.opcode_ast), unquote(op.reg_ast), unquote(op.meta_ast)) do
          unquote(op.code_ast)
        end
      end
    end

    def to_ast(op) do
      {:def, [context: Elixir, import: Kernel],
      [
        {:when, [context: Elixir],
         [
           {op.type, [], [op.opcode_ast, op.reg_ast, op.meta_ast]},
           op.guard_ast
         ]},
        [do: op.code_ast]
      ]}
    end
  end

  def macro_inspect(code_ast, label \\ nil) do
    prefix = if label, do: "\n#{label}: ", else: ""
    IO.puts(prefix <> Macro.to_string(code_ast))
    code_ast
  end

  defmacro __using__(opts) do

    debug_dump_code = if opts[:debug_dump_code] do
      quote do @debug_dump_code true end
    end

    quote do
      @behaviour Type.Engine.Api

      import Type, only: :macros

      import Type.Inference.Opcodes, only: [
        opcode: 2, forward: 4, forward: 3, forward: 1, backprop: 4, backprop: 1,
        put_reg: 3, fetch_type: 2, merge_reg: 2, tombstone: 2, is_defined: 2]

      Module.register_attribute(__MODULE__, :operations, accumulate: true)

      unquote(debug_dump_code)

      @before_compile Type.Inference.Opcodes
    end
  end

  defmacro __before_compile__(%{module: module}) do
    ops = module
    |> Module.get_attribute(:operations)
    |> List.wrap
    |> Enum.group_by(&(&1.type))

    last_fwd = quote do
      def forward(_, _, _), do: :unknown
    end
    last_bck = quote do
      def backprop(_, _, _), do: :unknown
    end

    code = {:__block__, [], Enum.reverse(
      [last_bck | Operations.rebuild(ops[:backprop])] ++
      [last_fwd | Operations.rebuild(ops[:forward])])}

    Module.get_attribute(module, :debug_dump_code) && (macro_inspect(code))

    code
  end

  ### KEY MACROS

  defmacro opcode(opcode_ast, do: {:__block__, meta, code}) do
    if __CALLER__.module == TypeTest.Abstract.OpcodeFrameworkTest do
      code |> IO.inspect(label: "83")
    end
    Module.put_attribute(__CALLER__.module, :current_opcode, opcode_ast)

    rewritten_code = Enum.map(code, &rewrite_whens/1)

    {:__block__, meta, rewritten_code}
  end
  defmacro opcode(opcode_ast, do: opcode_block_ast) do
    Module.put_attribute(__CALLER__.module, :current_opcode, opcode_ast)

    opcode_block_ast
  end
  defmacro opcode(opcode_ast, :unimplemented) do
    a = assemble_noop(opcode_ast, :forward, warn: "the opcode #{Macro.to_string opcode_ast} is not implemented yet.")
    b = assemble_noop(opcode_ast, :backprop)

    quote do
      @forward unquote(Macro.escape(a))
      @backprop unquote(Macro.escape(b))
    end
  end
  defmacro opcode(opcode_ast, :noop) do
    a = assemble_noop(opcode_ast, :forward)
    b = assemble_noop(opcode_ast, :backprop)

    quote do
      @forward unquote(Macro.escape(a))
      @backprop unquote(Macro.escape(b))
    end
  end

  defmacro forward(reg_ast, meta_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    stash(__CALLER__.module,
      type: :forward,
      reg_ast: reg_ast,
      meta_ast: meta_ast,
      code_ast: code_ast)
  end

  defmacro forward(mode) when mode in [:noop, :unimplemented] do
    stash(__CALLER__.module,
      type: :forward,
      code_ast: mode)
  end

  defmacro forward(reg_ast, meta_ast, guards_and_code) do
    {guard, code} = split(guards_and_code)
    stash(__CALLER__.module,
      type: :forward,
      reg_ast: reg_ast,
      meta_ast: meta_ast,
      code_ast: code,
      guard_ast: guard)
  end

  defmacro backprop(reg_ast, meta_ast, {:..., _, _}, do: code_ast) do
    stash(__CALLER__.module,
      type: :backprop,
      reg_ast: reg_ast,
      meta_ast: meta_ast,
      code_ast: code_ast)
  end

  defmacro backprop(mode) when mode in [:noop, :unimplemented] do
    stash(__CALLER__.module,
    type: :backprop,
    code_ast: mode)
  end
  defmacro backprop(:terminal) do
    # don't implement it.  This should cause it to raise at the end of the module cascade.
    quote do end
  end

  defp make_warn(string) do quote do IO.warn(unquote(string)) end end
  defp assemble_noop(opcode_ast, symbol, opts \\ []) do
    warning = case opts[:warn] do
      true -> make_warn("the method #{symbol} for opcode #{Macro.to_string opcode_ast} is not implemented.")
      nil -> nil
      false -> nil
      _ -> make_warn(opts[:warn])
    end

    ok_state = case symbol do
      :forward -> {:ok, {:state, [], Elixir}}
      :backprop -> {:ok, [{:state, [], Elixir}]}
    end

    {:def, [context: Elixir, import: Kernel],
    [
      {symbol, [context: Elixir], [opcode_ast, {:state, [], Elixir}, {:_meta, [], Elixir}]},
      [do: {:__block__, [], [warning, ok_state]}]
    ]}
  end

  @typep stash_params :: [
    type: :forward | :backprop,
    code_ast: Macro.t | :noop | :unimplemented,
    reg_ast: Macro.t | nil,
    meta_ast: Macro.t | nil,
    when_clauses: Macro.t | nil
  ]

  @spec stash(module, stash_params) :: Macro.t
  defp stash(module, params) do
    current_opcode = Module.get_attribute(module, :current_opcode)
    operation = struct(Operations, params ++ [opcode_ast: current_opcode])
    quote do
      @operations unquote(Macro.escape(operation))
    end
  end

  # exports
  defguard is_defined(state, reg) when
    is_nil(reg) or
    (is_tuple(reg) and (elem(reg, 0) in [:atom, :integer, :literal])) or
    (is_tuple(reg) and
    (reg
    |> elem(0)
    |> :erlang.map_get(state)
    |> is_map_key(elem(reg, 1))))

  def fetch_type(state, {:x, reg}), do: state.x[reg]
  def fetch_type(state, {:y, reg}), do: state.y[reg]
  def fetch_type(_state, nil), do: []
  def fetch_type(_state, {_, value}), do: Type.of(value)

  def put_reg(state, {class, reg}, type) do
    %{state | class => Map.put(state.x, reg, type)}
  end

  def merge_reg(state, registers) do
    %{state | x: Map.merge(state.x, registers)}
  end
  def tombstone(state, register) do
    %{state | x: Map.delete(state.x, register)}
  end

  defp filter_params(opcode_ast, code_ast) do
    unused = opcode_ast
    |> get_variables
    |> Enum.reject(&String.starts_with?(Atom.to_string(&1), "_"))
    |> Kernel.--(get_variables(code_ast))

    #opcode_ast
    substitute(opcode_ast, unused)
  end

  def get_variables({atom, _, ctx}) when is_atom(ctx), do: [atom]
  def get_variables({a, b}) do
    Enum.flat_map([a, b], &get_variables/1)
  end
  def get_variables({_, _, list}) do
    get_variables(list)
  end
  def get_variables(list) when is_list(list) do
    Enum.flat_map(list, &get_variables/1)
  end
  def get_variables(_), do: []

  defp substitute(any, []), do: any
  defp substitute({atom, meta, ctx}, unused) when is_atom(ctx) do
    {substitute(atom, unused), meta, ctx}
  end
  defp substitute({call, meta, list}, unused) when is_list(list) do
    {call, meta, substitute(list, unused)}
  end
  defp substitute({a, b}, unused) do
    {substitute(a, unused), substitute(b, unused)}
  end
  defp substitute(list, unused) when is_list(list) do
    Enum.map(list, &substitute(&1, unused))
  end
  defp substitute(atom, unused) do
    if atom in unused, do: String.to_atom("_#{atom}"), else: atom
  end

  defp rewrite_whens({:when, _meta,
      [{:forward, _, [state_ast, meta_ast, {:..., _, _}]}, clauses]}) do
    quote do forward(unquote(state_ast), unquote(meta_ast), unquote(clauses)) end
  end
  defp rewrite_whens(code), do: code

  defp split({guard, meta, args}) do
    last_arg = List.last(args)
    case last_arg do
      [do: code] ->
        {{guard, meta, all_but_last(args)}, code}
      other ->
        {next_guard, next_code} = split(other)
        {{guard, meta, all_but_last(args) ++ [next_guard]}, next_code}
    end
  end

  defp all_but_last(lst) do
    Enum.take(lst, length(lst) - 1)
  end
end
