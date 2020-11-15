defmodule Type.Inference.Application.BlockCache do
  @moduledoc false

  ## this GenServer encapsulates an ETS table and sequences
  ## reads and writes out of it.
  ## The ETS table holds the following types of values:
  ## - {module, state} where state in :started, :finished

  use GenServer

  alias Type.Inference.Application.ModuleAnalyzer

  import Logger

  @pubsub Type.Inference.Dependency.PubSub

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, :ets.new(__MODULE__, [:set])}
  end

  #######################################################################
  # API

  ## depend_on

  @spec depend_on(Block.dep, keyword) :: Block.t
  def depend_on(dep, opts \\ []) do
    # Pull the process's self-identity from the Process dictionary.
    self_id = Process.get(:block_id)
    # debug options
    strict = Keyword.get(opts, :strict, true)
    module_analyzer = Keyword.get(opts, :module_analyzer, ModuleAnalyzer)

    Registry.register(@pubsub, dep, ml(self_id))

    case GenServer.call(__MODULE__, {:depend_on, dep, self_id}) do
      {:ok, block} -> block
      :missing when strict ->
        raise Type.InferenceError, message: dep_to_msg(dep)
      :no_module when strict ->
        dep
        |> elem(0)
        |> module_analyzer.run

        wait_for(dep)
      :wait ->
        wait_for(dep)
      _ ->
        wait_for(dep)
    end
  after
    Registry.unregister(@pubsub, dep)
  end

  defp depend_on_impl(dep, self_id, _from, table) do
    # before registering the dependency, attempt to resolve circular
    # dependencies; those will be collapsed.
    search_for_circular_dep(dep, self_id)

    # warning: inverted with block.
    with []            <- :ets.match(table, {dep, :"$1"}),
         [[:finished]] <- :ets.match(table, {elem(dep, 0), :"$1"}) do
      {:reply, :missing, table}
    else
      [[:started]] -> {:reply, :wait, table}
      []           -> {:reply, :no_module, table}
      [[block]]    -> {:reply, {:ok, block}, table}
    end

  catch
    {:circular, circ} ->
      # a provisional response that will deal with resolving circular
      # references, later.
      Logger.debug("circular reference between #{inspect self_id} and #{inspect circ} found.")
      {:reply, {:ok, %Type{name: :none}}, table}
  end

  defp dep_to_msg({m, f, a}), do: "the module #{inspect m} does not have function #{f}/#{a}"
  defp dep_to_msg({m, l}), do: "the module #{inspect m} does not have label #{l}"

  defp wait_for(dep) do
    pid = dep
    |> elem(0)
    |> ModuleAnalyzer.lookup()

    ref = if pid, do: Process.monitor(pid)

    receive do
      {:block, ^dep, block} -> block
      {:DOWN, ^ref, :process, ^pid, reason} ->
        raise Type.InferenceError,
          message: "waiting for module #{dep |> elem(0) |> inspect} analysis to finish, crashed due to #{reason}"
    end
  end

  defp search_for_circular_dep(_, nil), do: nil
  defp search_for_circular_dep(dep, self_id) do
    mfa_self = mfa(self_id)
    ml_self = ml(self_id)
    # first, find the target for dep.
    Registry.select(@pubsub, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(&(dep == elem(&1, 1)))
    |> Enum.each(fn
      {^mfa_self, circ} -> throw {:circular, circ}
      {^ml_self, circ} -> throw {:circular, circ}
      {next_hop, _} ->
        search_for_circular_dep(next_hop, self_id)
    end)
  end

  ## resolve

  @spec resolve(Block.id, Block.t) :: :ok
  def resolve(block_id, block) do
    GenServer.call(__MODULE__, {:resolve, block_id, block})
  end
  defp resolve_impl(block_id = {_, nil, _}, block, _from, table) do
    # leave {{mod, label}, block} in the ETS table.
    :ets.insert(table, {ml(block_id), block})
    broadcast(block_id, block)
    {:reply, :ok, table}
  end
  defp resolve_impl(block_id, block, from, table) do
    # leave {mfa, block} in the ETS table.
    :ets.insert(table, {mfa(block_id), block})
    broadcast(block_id, block)
    resolve_impl(remove_fa(block_id), block, from, table)
  end

  @spec broadcast(Block.id, Block.t) :: :ok
  @doc false  # this function is public for testing purposes only.
  def broadcast({module, nil, label}, block) do
    dispatch({module, label}, block)
  end
  def broadcast({module, {function, arity}, label}, block) do
    dispatch({module, function, arity}, block)
    broadcast({module, nil, label}, block)
  end
  @spec dispatch(Block.dep, Block.t) :: :ok
  defp dispatch(key, block) do
    Registry.dispatch(@pubsub, key, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:block, key, block})
    end)
  end

  ## start
  # informs the cache that work on the module has begun.
  # should be balanced by the `finish(module)` function.
  def start(module), do: GenServer.call(__MODULE__, {:start, module})
  def start_impl(module, {who, _}, table) do
    :ets.insert(table, {module, {:started, who}})
    {:reply, :ok, table}
  end

  ## finish

  # This function should be called by ModuleAnalyzer to report to the
  # ETS state machine that work on all of the functions in this module
  # has been completed.  Flips the state of the module entry in the
  # table to :finished
  def finish(module), do: GenServer.call(__MODULE__, {:finish, module})
  defp finish_impl(module, _from, table) do
    :ets.insert(table, {module, :finished})
    {:reply, :ok, table}
  end

  defp mfa({module, {function, arity}, _label}), do: {module, function, arity}
  defp mfa({_, nil, _}), do: nil
  defp mfa(nil), do: nil
  defp ml({module, _, label}), do: {module, label}
  defp ml(nil), do: nil
  defp remove_fa({module, _, label}), do: {module, nil, label}

  #############################################################################
  # ROUTER

  @impl true
  def handle_call({:depend_on, dep, self_id}, from, table) do
    depend_on_impl(dep, self_id, from, table)
  end
  def handle_call({:resolve, block_id, block}, from, table) do
    resolve_impl(block_id, block, from, table)
  end
  def handle_call({:start, module}, from, table) do
    start_impl(module, from, table)
  end
  def handle_call({:finish, module}, from, table) do
    finish_impl(module, from, table)
  end

end
