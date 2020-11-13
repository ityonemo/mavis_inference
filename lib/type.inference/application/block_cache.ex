defmodule Type.Inference.Application.BlockCache do
  @moduledoc false

  use GenServer

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
  def depend_on(dependency) do
    # Pull the process's self-identity from the Process dictionary.
    self_descriptor = Process.get(:block_spec)
    Registry.register(@pubsub, dependency, self_descriptor)
    if block = GenServer.call(__MODULE__, {:depend_on, dependency}) do
      block
    else
      wait_for(dependency)
    end
  after
    Registry.unregister(@pubsub, dependency)
  end

  defp depend_on_impl(dependency, _from, table) do
    case :ets.match(table, match_for(dependency)) do
      [[block]] -> {:reply, block, table}
      [] -> {:reply, nil, table}
    end
  end

  defp wait_for(dependency) do
    receive do
      {:block, ^dependency, block} -> block
    end
  end

  ## resolve

  @spec resolve(Block.id, Block.t) :: :ok
  def resolve(block_id, block) do
    GenServer.call(__MODULE__, {:resolve, block_id, block})
  end
  defp resolve_impl(block_id = {module, fa = {_, _}, label}, block, from, table) do
    :ets.insert(table, insert_for({module, fa}, block))
    broadcast(block_id, block)
    resolve_impl({module, nil, label}, block, from, table)
  end
  defp resolve_impl(block_id = {module, nil, label}, block, _from, table) do
    :ets.insert(table, insert_for({module, label}, block))
    broadcast(block_id, block)
    {:reply, :ok, table}
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

  ## ETS HELPERS
  defp match_for({module, function, arity}) do
    {{module, function, arity}, :"$1"}
  end
  defp match_for({module, label}) do
    {{module, label}, :"$1"}
  end

  defp insert_for({module, {function, arity}}, block) do
    {{module, function, arity}, block}
  end
  defp insert_for({module, label}, block) do
    {{module, label}, block}
  end

  #############################################################################
  # ROUTER

  @impl true
  def handle_call({:depend_on, dependency}, from, table) do
    depend_on_impl(dependency, from, table)
  end
  def handle_call({:resolve, block_id, block}, from, table) do
    resolve_impl(block_id, block, from, table)
  end

end
