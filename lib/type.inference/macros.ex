defmodule Type.Inference.Macros do
  defmacro __using__(_) do
    quote do
      @behaviour Type.Engine.Api

      import Type.Inference.Macros, only: [
        opcode: 2, forward: 4, forward: 1, backprop: 4, backprop: 1,
        put_reg: 3, get_reg: 2, merge_reg: 2, tombstone: 2]

      Module.register_attribute(__MODULE__, :forward, accumulate: true)
      Module.register_attribute(__MODULE__, :backprop, accumulate: true)

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

    {:__block__, [], Enum.reverse([last_bck | bck] ++ [last_fwd | fwd])}
  end


  ### KEY MACROS

  defmacro opcode(opcode_ast, do: opcode_block_ast) do
    Module.put_attribute(__CALLER__.module, :current_opcode, opcode_ast)
    opcode_block_ast
  end
  defmacro opcode(opcode_ast, :unimplemented) do
    empty_opcode(opcode_ast, warn: true)
  end
  defmacro opcode(opcode_ast, :noop) do
    empty_opcode(opcode_ast)
  end

  defmacro forward(state_param_ast, meta_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> filter_params([state_param_ast, code_ast])
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
    |> filter_params([state_param_ast, code_ast])
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

  defp empty_opcode(opcode_ast, opts \\ []) do
    warning = if opts[:warn] do
      opcode = Macro.to_string(opcode_ast)
      quote do
        IO.warn("the opcode #{unquote opcode} is not implemented yet.")
      end
    end

    a = Macro.escape(quote do
      def forward(unquote(opcode_ast), state) do
        unquote(warning)
        {:ok, state}
      end
    end)

    b = Macro.escape(quote do
      def backprop(unquote(opcode_ast), state) do
        {:ok, [state]}
      end
    end)

    quote do
      unquote(stash(a, :forward))
      unquote(stash(b, :backprop))
    end
  end

  defp assemble_noop(opcode_ast, symbol, opts \\ []) do
    warning = if opts[:warn] do
      opcode = Macro.to_string(opcode_ast)
      quote do
        IO.warn("the method #{unquote symbol} for opcode #{unquote opcode} is not implemented.")
      end
    end

    ok_state = case symbol do
      :forward -> {:ok, {:state, [], Elixir}}
      :backprop -> {:ok, [{:state, [], Elixir}]}
    end

    {:def, [context: Elixir, import: Kernel],
    [
      {symbol, [context: Elixir], [opcode_ast, {:state, [], Elixir}]},
      [do: {:__block__, [], [warning, ok_state]}]
    ]}
  end

  defp assemble(opcode_ast, state_param_ast, meta_ast, code_ast, symbol) do
    quote do
      def unquote(symbol)(unquote(opcode_ast), unquote(meta_ast), unquote(state_param_ast)) do
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
  def put_reg(state, reg, type) do
    %{state | x: Map.put(state.x, reg, type)}
  end
  def get_reg(state, reg) do
    state.x[reg]
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
