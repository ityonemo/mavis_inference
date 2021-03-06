defmodule Type.Inference.Opcodes do

  @moduledoc """
  ## options:
  - debug_dump_code: if true then dumps the code at the end.
  """

  @enforce_keys [:opcode_ast, :guard_ast]
  defstruct @enforce_keys

  @typedoc """
  describes the external framework describing properties common to
  all forward and backprop functions generated relative to a single
  opcode descriptor
  """
  @type t :: %__MODULE__{
    opcode_ast: Macro.t,
    guard_ast: Macro.t | nil
  }

  defmodule Operations do
    @blank {:_, [], nil}
    @enforce_keys ~w(type opcode_ast code_ast line)a
    defstruct @enforce_keys ++ [reg_ast: @blank, meta_ast: @blank, guard_ast: nil]

    @type t :: %__MODULE__{
      type: :forward,
      opcode_ast: Macro.t,
      code_ast: Macro.t | :noop | :unimplemented,
      line: pos_integer,
      reg_ast: Macro.t,
      meta_ast: Macro.t,
      guard_ast: Macro.t | nil,
    } | %__MODULE__{
      type: :backprop,
      opcode_ast: Macro.t,
      code_ast: Macro.t | :noop | :unimplemented,
      line: pos_integer,
      reg_ast: {Macro.t, Macro.t},
      meta_ast: Macro.t,
      guard_ast: Macro.t | nil,
    }

    @spec rebuild(nil | [t]) :: [Macro.t]
    def rebuild(nil), do: []
    def rebuild(op_list) do
      Enum.map(op_list, &to_ast/1)
    end

    @spec to_ast(t) :: Macro.t
    def to_ast(op! = %{guard_ast: nil}) do
      op! = op!
      |> opcode_reline
      |> opcode_silence

      quote line: op!.line do
        def unquote(op!.type)(unquote(op!.opcode_ast), unquote(op!.reg_ast), unquote(op!.meta_ast)) do
          unquote(op!.code_ast)
        end
      end
    end

    def to_ast(op!) do
      op! = op!
      |> opcode_reline
      |> opcode_silence

      {:def, [context: Elixir, import: Kernel, line: op!.line],
      [
        {:when, [context: Elixir, line: op!.line],
         [
           {op!.type, [line: op!.line], [op!.opcode_ast, op!.reg_ast, op!.meta_ast]},
           op!.guard_ast
         ]},
        [do: op!.code_ast]
      ]}
    end

    # maniplates the ast of the opcode so that the line number for the
    # function header matches the location in the parent.
    defp opcode_reline(op) do
      %{op | opcode_ast: substitute_line(op.opcode_ast, op.line)}
    end

    defp substitute_line({id, meta, params}, line) when is_list(params) do
      {id, Keyword.put(meta, :line, line), Enum.map(params, &substitute_line(&1, line))}
    end
    defp substitute_line({id, meta, atom}, line) when is_atom(atom) do
      {id, Keyword.put(meta, :line, line), atom}
    end
    defp substitute_line(list, line) when is_list(list) do
      Enum.map(list, &substitute_line(&1, line))
    end
    defp substitute_line({a, b}, line) do
      {substitute_line(a, line), substitute_line(b, line)}
    end
    defp substitute_line(other,_), do: other

    # manipulates the AST so that unused variable warnings are silenced,
    # because a general opcode operation definition might use more opcodes
    # than are actually used by the body of the function.
    defp opcode_silence(operation = %{opcode_ast: opcode_ast}) do
      unused = opcode_ast
      |> get_variables
      |> Enum.reject(&String.starts_with?(Atom.to_string(&1), "_"))
      |> Kernel.--(get_variables(operation.code_ast))
      |> Kernel.--(get_variables(operation.reg_ast))
      |> Kernel.--(get_variables(operation.meta_ast))
      |> Kernel.--(get_variables(operation.guard_ast))

      #opcode_ast
      %{operation | opcode_ast: substitute(opcode_ast, unused)}
    end

    defp get_variables({atom, _, ctx}) when is_atom(ctx), do: [atom]
    defp get_variables({a, b}) do
      Enum.flat_map([a, b], &get_variables/1)
    end
    defp get_variables({params, _, list}) do
      get_variables(params) ++ get_variables(list)
    end
    defp get_variables(list) when is_list(list) do
      Enum.flat_map(list, &get_variables/1)
    end
    defp get_variables(_), do: []

    defp substitute(any, []), do: any
    defp substitute({atom, meta, ctx}, unused) when is_atom(ctx) do
      {substitute(atom, unused), meta, ctx}
    end
    defp substitute({call, meta, list}, unused) when is_list(list) do
      {substitute(call, unused), meta, substitute(list, unused)}
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
        # key macros
        opcode: 2, opcode: 3,
        forward: 4, forward: 3, forward: 1,
        backprop: 5, backprop: 4, backprop: 1,
        # key helpers
        put_reg: 3, get_reg: 2, merge_reg: 2, tombstone: 2,
        # other helpers
        zero_reg: 0,
        # guards
        is_defined: 2, is_reg: 3, is_reg_in: 3]

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

  @reg {:reg, [], Elixir}

  defmacro opcode(opcode_ast, whens \\ [], block)
  defmacro opcode(opcode_ast, whens, do: {:__block__, meta, code}) do
    set_opcode(__CALLER__.module, opcode_ast, whens[:when])

    rewritten_code = Enum.map(code, &rewrite_whens/1)

    {:__block__, meta, rewritten_code}
  end
  defmacro opcode(opcode_ast, whens, do: opcode_block_ast) do
    set_opcode(__CALLER__.module, opcode_ast, whens[:when])

    rewrite_whens(opcode_block_ast)
  end
  defmacro opcode(opcode_ast, whens, :unimplemented) do
    module = __CALLER__.module
    set_opcode(module, opcode_ast, whens[:when])

    quote do
      unquote(stash(
        module,
        type: :forward,
        reg_ast: @reg,
        code_ast: :unimplemented
      ))
      unquote(stash(
        module,
        type: :backprop,
        reg_ast: @reg,
        code_ast: :unimplemented
      ))
    end
  end
  defmacro opcode(opcode_ast, whens, :noop) do
    module = __CALLER__.module
    set_opcode(module, opcode_ast, whens[:when])

    quote do
      unquote(stash(
        module,
        type: :forward,
        reg_ast: @reg,
        code_ast: :noop
      ))
      unquote(stash(
        module,
        type: :backprop,
        reg_ast: @reg,
        code_ast: :noop
      ))
    end
  end

  defp rewrite_whens({:when, _meta,
      [{:forward, _, [regs_ast, meta_ast, {:..., _, _}]}, clauses]}) do
    quote do
      forward(unquote(regs_ast), unquote(meta_ast), unquote(clauses))
    end
  end
  defp rewrite_whens({:when, _meta,
      [{:backprop, _, [out_regs_ast, in_regs_ast, meta_ast, {:..., _, _}]}, clauses]}) do
    quote do
      backprop(unquote(out_regs_ast), unquote(in_regs_ast), unquote(meta_ast), unquote(clauses))
    end
  end
  defp rewrite_whens(code), do: code

  defp set_opcode(module, opcode_ast, guard_ast) do
    Module.put_attribute(module, :current_opcode, %__MODULE__{
      opcode_ast: opcode_ast,
      guard_ast: guard_ast
    })
  end

  # picks up the line number from the ast of the register AST.
  # for some reason, more reliable than taking it from __CALLER__.line
  defp get_line(reg_ast), do: reg_ast |> elem(1) |> Keyword.get(:line)

  defmacro forward(reg_ast, meta_ast, {:..., _, _}, do: code_ast) do
    # retrieve the opcode.
    stash(__CALLER__.module,
      type: :forward,
      line: get_line(reg_ast),
      reg_ast: reg_ast,
      meta_ast: meta_ast,
      code_ast: code_ast)
  end

  defmacro forward(reg_ast, meta_ast, guards_and_code) do
    {guard, code} = split(guards_and_code)
    stash(__CALLER__.module,
      type: :forward,
      line: get_line(reg_ast),
      reg_ast: reg_ast,
      meta_ast: meta_ast,
      code_ast: code,
      guard_ast: guard)
  end

  defmacro forward(mode) when mode in [:noop, :unimplemented] do
    stash(__CALLER__.module,
      type: :forward,
      line: __CALLER__.line,
      code_ast: mode)
  end

  defmacro backprop(out_reg_ast, in_reg_ast, meta_ast, {:..., _, _}, do: code_ast) do
    stash(__CALLER__.module,
      type: :backprop,
      line: get_line(out_reg_ast),
      reg_ast: {out_reg_ast, in_reg_ast},
      meta_ast: meta_ast,
      code_ast: code_ast)
  end

  defmacro backprop(out_reg_ast, in_reg_ast, meta_ast, guards_and_code) do
    {guard, code} = split(guards_and_code)
    stash(__CALLER__.module,
      type: :backprop,
      line: get_line(out_reg_ast),
      reg_ast: {out_reg_ast, in_reg_ast},
      meta_ast: meta_ast,
      code_ast: code,
      guard_ast: guard)
  end

  defmacro backprop(mode) when mode in [:noop, :unimplemented] do
    stash(__CALLER__.module,
    type: :backprop,
    line: __CALLER__.line,
    code_ast: mode)
  end

  defmacro backprop(:terminal) do
    # don't implement it.  This should cause it to raise at the end of the module cascade.
    # TODO: make this more sophisticated
    quote do end
  end

  @typep stash_params :: [
    type: :forward | :backprop,
    line: pos_integer,
    code_ast: Macro.t | :noop | :unimplemented,
    reg_ast: Macro.t | {Macro.t, Macro.t} | nil,
    meta_ast: Macro.t | nil,
    guard_ast: Macro.t | nil
  ]

  @spec stash(module, stash_params) :: Macro.t
  defp stash(module, params!) do
    current_opcode = Module.get_attribute(module, :current_opcode)

    params! = Keyword.merge(params!,
      opcode_ast: current_opcode.opcode_ast,
      guard_ast: guard_merge(params![:guard_ast], current_opcode.guard_ast)
    )

    operation = Operations
    |> struct(params!)
    |> Macro.escape

    quote do
      @operations unquote(operation)
    end
  end

  defp guard_merge(nil, nil), do: nil
  defp guard_merge(grd, nil), do: grd
  defp guard_merge(nil, grd), do: grd
  defp guard_merge(gra, grb) do
    {:and, [], [gra, grb]}
  end

  @spec split(Macro.t) :: {Macro.t, Macro.t}
  # splits an "oddly created" with statement into its "true" with statement
  # and the code resulting from a do: statement.
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

  ###########################################################################
  # EXPORTED GUARDS, MACROS, and FUNCTIONS

  defguard is_defined(regs, reg_or_const) when
    is_nil(reg_or_const) or
    (is_tuple(reg_or_const) and
    (elem(reg_or_const, 0) in [:atom, :integer, :literal])) or
    (is_tuple(reg_or_const) and
    (reg_or_const
    |> elem(0)
    |> :erlang.map_get(regs)
    |> is_map_key(elem(reg_or_const, 1))))

  defguard is_reg(regs, reg, value) when
    (reg
    |> elem(1)
    |> :erlang.map_get(:erlang.map_get(elem(reg, 0), regs))) == value

  defmacro is_reg_in(regs, reg, list) do
    quote do
      (unquote(reg)
      |> elem(1)
      |> :erlang.map_get(
        :erlang.map_get(elem(unquote(reg), 0), unquote(regs)))) in unquote(list)
    end
  end

  def get_reg(regs, {:x, reg}), do: regs.x[reg]
  def get_reg(regs, {:y, reg}), do: regs.y[reg]
  def get_reg(_regs, nil), do: []
  def get_reg(_regs, {_, value}), do: Type.of(value)

  def put_reg(regs, {class, reg}, type) do
    %{regs | class => Map.put(regs.x, reg, type)}
  end

  def merge_reg(regs, registers) do
    %{regs | x: Map.merge(regs.x, registers)}
  end
  def tombstone(regs, register) do
    %{regs | x: Map.delete(regs.x, register)}
  end

  # this register is special
  def zero_reg, do: {:x, 0}
end
