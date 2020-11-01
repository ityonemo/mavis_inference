defmodule Type.Inference.Macros do

  @moduledoc """
  ## options:
  - debug_dump_code: if true then dumps the code at the end.
  """

  defp macro_inspect(code_ast, label \\ nil) do
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

      import Type.Inference.Macros, only: [
        opcode: 2, forward: 4, forward: 1, backprop: 4, backprop: 1,
        put_reg: 3, fetch_type: 2, merge_reg: 2, tombstone: 2, is_defined: 2]

      Module.register_attribute(__MODULE__, :forward, accumulate: true)
      Module.register_attribute(__MODULE__, :backprop, accumulate: true)

      unquote(debug_dump_code)

      @before_compile Type.Inference.Macros
    end
  end

  defmacro __before_compile__(env) do
    caller = env.module
    fwd = List.wrap(Module.get_attribute(caller, :forward))
    bck = List.wrap(Module.get_attribute(caller, :backprop))

    last_fwd = quote do
      def forward(_, _, _), do: :unknown
    end
    last_bck = quote do
      def backprop(_, _, _), do: :unknown
    end

    code = {:__block__, [], Enum.reverse([last_bck | bck] ++ [last_fwd | fwd])}

    if Module.get_attribute(caller, :debug_dump_code) do
      code |> macro_inspect
    end

    code
  end

  ### KEY MACROS

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

  defmacro forward(state_param_ast, meta_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> filter_params([state_param_ast, code_ast, meta_ast])
    |> assemble(state_param_ast, meta_ast, code_ast, :forward)
    |> Macro.escape
    |> stash(:forward)
  end

  defmacro forward(mode) when mode in [:noop, :unimplemented] do
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> filter_params([])
    |> assemble_noop(:forward, warn: (mode == :unimplemented))
    |> Macro.escape
    |> stash(:forward)
  end

  defmacro backprop(state_param_ast, meta_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> filter_params([state_param_ast, code_ast, meta_ast])
    |> assemble(state_param_ast, meta_ast, code_ast, :backprop)
    |> Macro.escape
    |> stash(:backprop)
  end

  defmacro backprop(mode) when mode in [:noop, :unimplemented] do
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> filter_params([])
    |> assemble_noop(:backprop, warn: (mode == :unimplemented))
    |> Macro.escape
    |> stash(:backprop)
  end
  defmacro backprop(:terminal) do
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

  defp assemble(opcode_ast, state_param_ast, meta_ast, code_ast, symbol) do
    quote do
      def unquote(symbol)(unquote(opcode_ast), unquote(state_param_ast), unquote(meta_ast)) do
        unquote(code_ast)
      end
    end
  end

  defp stash(ast, symbol) do
    {:@, [context: Type.Inference.Macros, import: Kernel],
    [
      {symbol, [context: Type.Inference.Macros], [ast]}
    ]}
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

end
