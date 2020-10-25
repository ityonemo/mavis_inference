defmodule Type.Inference.Macros do
  defmacro __using__(_) do
    quote do
      @behaviour Type.Engine.Api

      import Type.Inference.Macros, only: [opcode: 1, opcode: 2]

      Module.register_attribute(__MODULE__, :forward, accumulate: true)
      Module.register_attribute(__MODULE__, :backprop, accumulate: true)

      @before_compile Type.Inference.Macros
    end
  end

  defmacro opcode(a, do: b) do
    opcode_impl(a, b)
  end
  defmacro opcode(op_ast) do
    fwd = quote do
      def forward(unquote(op_ast), registers), do: {:ok, registers}
    end
    bck = quote do
      def backprop(unquote(op_ast), registers), do: {:ok, [registers]}
    end

    quote do
      @forward unquote(Macro.escape(fwd))
      @backprop unquote(Macro.escape(bck))
    end
  end

  @blank {:state, [], Elixir}

  def opcode_impl(op_ast, ast) do
    {fwd_asts, freg_asts, bck_asts, breg_asts} = case ast do
      {:__block__, _, headers} ->
        funs = Enum.group_by(headers,
          fn {key, _, _} -> key end,
          fn
            {_, _, [reg_ast, {:..., _, _}, [do: code_ast]]} ->
              {reg_ast, code_ast}
            {:backprop, _, [:terminal]} -> {:_, terminal_ast(op_ast)}
          end)

        {freg_asts, fwd_asts} = unzip(funs.forward)
        {breg_asts, bck_asts} = unzip(List.wrap(funs[:backprop]))

        {fwd_asts, freg_asts, bck_asts, breg_asts}
      {:forward, _, [reg_ast, [do: fwd_ast]]} ->

        {fwd_ast, reg_ast, {:ok, [@blank]}, @blank}
      :unimplemented ->
        {unimp_warn(op_ast), @blank, {:ok, [@blank]}, @blank}
    end

    rebuild_functions(List.wrap(bck_asts), List.wrap(breg_asts), op_ast, :backprop) ++
    rebuild_functions(List.wrap(fwd_asts), List.wrap(freg_asts), op_ast, :forward)
  end

  defp unimp_warn(op_ast) do
    msg = "the opcode #{inspect op_ast} is not implemented yet."
    {:__block__, [], [
      quote do
        IO.warn(unquote(msg))
      end,
      {:ok, @blank}
    ]}
  end

  defp terminal_ast(op_ast) do
    message = "opcode #{inspect op_ast} is supposed to be terminal"
    quote do
      raise unquote(message)
    end
  end

  defp rebuild_functions(code_asts, reg_asts, op_ast, mode) do
    code_asts
    |> Enum.zip(reg_asts)
    |> Enum.map(fn {code_ast, reg_ast} ->
      rebuild_function(code_ast, reg_ast, op_ast, mode)
    end)
  end

  defp rebuild_function(code_ast, reg_ast, op_ast, mode) do
    # to prevent compiler warnings that can happen if only some of
    # the variables are used
    free_vars = scan_free_vars(op_ast)

    suppressed_header = free_vars -- scan_free_vars(code_ast)

    fwd_op = suppress(op_ast, suppressed_header)

    func = quote do
      def unquote(mode)(unquote(fwd_op), unquote(reg_ast)) do
        unquote(code_ast)
      end
    end

    {:@, [context: Elixir, import: Kernel], [{mode, [context: Elixir], [Macro.escape(func)]}]}
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

  def unzip(list_of_tuples) do
    {ra, rb} = list_of_tuples
    |> Enum.reduce({[], []}, fn {sa, sb}, {da, db} ->
      {[sa | da], [sb | db]}
    end)
    {Enum.reverse(ra), Enum.reverse(rb)}
  end

  ################################################################
  ## DSL tools

  @var_endings [nil, Elixir]

  defp scan_free_vars({ast, _, params}) when is_list(params) do
    scan_free_vars(ast) ++ Enum.flat_map(params, &scan_free_vars/1)
  end
  defp scan_free_vars({a, _, b}) when is_atom(a) and b in @var_endings do
    case Atom.to_string(a) do
      "_" <> _ -> []
      _ -> [a]
    end
  end
  defp scan_free_vars({a, b}) do
    scan_free_vars(a) ++ scan_free_vars(b)
  end
  defp scan_free_vars(lst) when is_list(lst) do
    Enum.flat_map(lst, &scan_free_vars/1)
  end
  defp scan_free_vars(atom) when is_atom(atom), do: []
  defp scan_free_vars(number) when is_number(number), do: []
  defp scan_free_vars(binary) when is_binary(binary), do: []

  defp suppress(ast, []), do: ast
  defp suppress({ast, meta, params}, deadlist) when is_list(params) do
    {suppress(ast, deadlist), meta, Enum.map(params, &suppress(&1, deadlist))}
  end
  defp suppress({a, b}, deadlist) do
    {suppress(a, deadlist), suppress(b, deadlist)}
  end
  defp suppress({a, meta, b}, deadlist) when is_atom(a) and b in @var_endings do
    if a in deadlist do
      silenced_a = String.to_atom("_#{a}")
      {silenced_a, meta, b}
    else
      {a, meta, b}
    end
  end
  defp suppress(list, deadlist) when is_list(list) do
    Enum.map(list, &suppress(&1, deadlist))
  end
  defp suppress(any, _), do: any

end
