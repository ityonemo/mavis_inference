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
    |> Module.get_attribute(:current_opcode)
    |> assemble_noop(:forward, warn: (mode == :unimplemented))
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
      {symbol, [context: Elixir], [opcode_ast, {:state, [], Elixir}]},
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
