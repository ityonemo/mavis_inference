defmodule Type.Inference.Macros do
  defmacro __using__(_) do
    quote do
      @behaviour Type.Engine.Api

      import Type.Inference.Macros, only: [
        opcode: 2, forward: 3, forward: 1, backprop: 3, backprop: 1,
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

    last = quote do
      def forward(op, _) do
        raise Type.UnknownOpcodeError, opcode: op
      end
    end

    {:__block__, [], Enum.reverse(bck ++ [last | fwd])}
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

  defmacro forward(state_param_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> assemble(state_param_ast, code_ast, :forward)
    |> Macro.escape
    |> stash(:forward)
  end

  defmacro forward(mode) when mode in [:noop, :unimplemented] do
    __CALLER__.module
    |> Module.get_attribute(:current_opcode) |> IO.inspect(label: "64")
    |> assemble_noop(:forward, warn: [mode == :unimplemented])
    |> Macro.escape
    |> stash(:forward)
  end

  defmacro backprop(state_param_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> assemble(state_param_ast, code_ast, :backprop)
    |> Macro.escape
    |> stash(:backprop)
  end

  defmacro backprop(mode) when mode in [:noop, :unimplemented] do
    __CALLER__.module
    |> Module.get_attribute(:current_opcode)
    |> assemble_noop(:backprop, warn: [mode == :unimplemented])
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
    quote do
      def forward(unquote(opcode_ast), state) do
        unquote(warning)
        {:ok, state}
      end
      def backprop(unquote(opcode_ast), state) do
        {:ok, [state]}
      end
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
      {symbol, [context: Elixir], [{:_, [], Elixir}, {:state, [], Elixir}]},
      [do: {:__block__, [], [warning, ok_state]}]
    ]}
  end

  defp assemble(opcode_ast, state_param_ast, code_ast, symbol) do
    quote do
      def unquote(symbol)(unquote(opcode_ast), unquote(state_param_ast)) do
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


#  defp unimp_warn(op_ast) do
#    msg = "the opcode #{inspect op_ast} is not implemented yet."
#    {:__block__, [], [
#      quote do
#        IO.warn(unquote(msg))
#      end,
#      {:ok, @blank}
#    ]}
#  end
#
#  defp terminal_ast(op_ast) do
#    message = "opcode #{inspect op_ast} is supposed to be terminal"
#    quote do
#      raise unquote(message)
#    end
#  end
#
#  defp rebuild_functions(code_asts, reg_asts, op_ast, mode) do
#    code_asts
#    |> Enum.zip(reg_asts)
#    |> Enum.map(fn {code_ast, reg_ast} ->
#      rebuild_function(code_ast, reg_ast, op_ast, mode)
#    end)
#  end
#
#  defp rebuild_function(code_ast, reg_ast, op_ast, mode) do
#    # to prevent compiler warnings that can happen if only some of
#    # the variables are used
#    free_vars = scan_free_vars(op_ast)
#
#    suppressed_header = free_vars -- scan_free_vars(code_ast)
#
#    fwd_op = suppress(op_ast, suppressed_header)
#
#    func = quote do
#      def unquote(mode)(unquote(fwd_op), unquote(reg_ast)) do
#        unquote(code_ast)
#      end
#    end
#
#    {:@, [context: Elixir, import: Kernel], [{mode, [context: Elixir], [Macro.escape(func)]}]}
#  end
#
#
#  def unzip(list_of_tuples) do
#    {ra, rb} = list_of_tuples
#    |> Enum.reduce({[], []}, fn {sa, sb}, {da, db} ->
#      {[sa | da], [sb | db]}
#    end)
#    {Enum.reverse(ra), Enum.reverse(rb)}
#  end
#
#  ################################################################
#  ## DSL tools
#
#  @var_endings [nil, Elixir]
#
#  defp scan_free_vars({ast, _, params}) when is_list(params) do
#    scan_free_vars(ast) ++ Enum.flat_map(params, &scan_free_vars/1)
#  end
#  defp scan_free_vars({a, _, b}) when is_atom(a) and b in @var_endings do
#    case Atom.to_string(a) do
#      "_" <> _ -> []
#      _ -> [a]
#    end
#  end
#  defp scan_free_vars({a, b}) do
#    scan_free_vars(a) ++ scan_free_vars(b)
#  end
#  defp scan_free_vars(lst) when is_list(lst) do
#    Enum.flat_map(lst, &scan_free_vars/1)
#  end
#  defp scan_free_vars(atom) when is_atom(atom), do: []
#  defp scan_free_vars(number) when is_number(number), do: []
#  defp scan_free_vars(binary) when is_binary(binary), do: []
#
#  defp suppress(ast, []), do: ast
#  defp suppress({ast, meta, params}, deadlist) when is_list(params) do
#    {suppress(ast, deadlist), meta, Enum.map(params, &suppress(&1, deadlist))}
#  end
#  defp suppress({a, b}, deadlist) do
#    {suppress(a, deadlist), suppress(b, deadlist)}
#  end
#  defp suppress({a, meta, b}, deadlist) when is_atom(a) and b in @var_endings do
#    if a in deadlist do
#      silenced_a = String.to_atom("_#{a}")
#      {silenced_a, meta, b}
#    else
#      {a, meta, b}
#    end
#  end
#  defp suppress(list, deadlist) when is_list(list) do
#    Enum.map(list, &suppress(&1, deadlist))
#  end
#  defp suppress(any, _), do: any

  # exports

  def put_reg(state, reg, type) do
    %{state | xreg: Map.put(state.xreg, reg, type)}
  end
  def get_reg(state, reg) do
    state.xreg[reg]
  end
  def merge_reg(state, registers) do
    %{state | xreg: Map.merge(state.xreg, registers)}
  end
  def tombstone(state, register) do
    %{state | xreg: Map.delete(state.xreg, register)}
  end

end
