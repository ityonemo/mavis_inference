defmodule Type.Inference.Application.BlockCache do
  @moduledoc false

  use GenServer

  import Logger

  @pubsub Type.Inference.Dependency.PubSub

  # second type of K/V is mfa -> block

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, :ets.new(__MODULE__, [:set])}
  end

  #######################################################################
  # API

  ## depend_on

  @spec depend_on(Block.dep) :: Block.t
  def depend_on(dep) do
    # Pull the process's self-identity from the Process dictionary.
    self_id = Process.get(:block_id)
    Registry.register(@pubsub, dep, ml(self_id))
    if block = GenServer.call(__MODULE__, {:depend_on, dep, self_id}) do
      block
    else
      wait_for(dep)
    end
  after
    Registry.unregister(@pubsub, dep)
  end

  defp depend_on_impl(dep, self_id, _from, table) do
    # before registering the dependency, attempt to resolve circular
    # dependencies; those will be collapsed.
    search_for_circular_dep(dep, self_id)

    case :ets.match(table, {dep, :"$1"}) do
      [[block]] -> {:reply, block, table}
      [] -> {:reply, nil, table}
    end

  catch
    {:circular, circ} ->
      # a provisional response that will deal with resolving circular
      # references, later.
      Logger.debug("circular reference between #{inspect self_id} and #{inspect circ} found.")
      {:reply, %Type{name: :none}, table}
  end

  defp wait_for(dep) do
    receive do
      {:block, ^dep, block} -> block
    end
  end

  defp search_for_circular_dep(_, nil), do: nil
  defp search_for_circular_dep(dep, self_id) do
    mfa_self = mfa(self_id)
    ml_self = ml(self_id)
    # first, find the target for dep.
    Registry.select(@pubsub, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(&(dep == elem(&1, 0)))
    |> Enum.each(fn
      {^mfa_self, circ} -> throw {:circular, circ}
      {^ml_self, circ} -> throw {:circular, circ}
      {_, next_hop} ->
        search_for_circular_dep(next_hop, self_id)
    end)
  end


  ## resolve

  @spec resolve(Block.id, Block.t) :: :ok
  def resolve(block_id, block) do
    GenServer.call(__MODULE__, {:resolve, block_id, block})
  end
  defp resolve_impl(block_id = {_, nil, _}, block, _from, table) do
    :ets.insert(table, {ml(block_id), block})
    broadcast(block_id, block)
    {:reply, :ok, table}
  end
  defp resolve_impl(block_id, block, from, table) do
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

end
