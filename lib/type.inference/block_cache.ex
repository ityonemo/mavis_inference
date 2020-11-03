defmodule Type.Inference.BlockCache do
  use GenServer

  # this ETS table holds two different types of K/Vs.

  # first type of K/V is module -> state;
  #   absent module means "no queries made"
  #   state :wait means "register request and block till complete"
  #   state :done means "check the ETS table for the result"

  # second type of K/V is mfa -> block

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    :ets.new(__MODULE__, [:set, :public, :named_table])
    {:ok, %{}}
  end

  #######################################################################
  # API

  @spec request(mfa) :: Type.Inference.Block.t
  def request(mfa = {module, _, _}) do
    with [{^module, :done}] <- :ets.lookup(__MODULE__, module),
         [{^mfa, block}] <- :ets.lookup(__MODULE__, mfa) do
      {:ok, block}
    else
      [{^module, :wait}] ->
        {:ok, GenServer.call(__MODULE__, {:request, mfa})}
      [] ->
        :ets.insert_new(__MODULE__, {module, :wait})
        fetch_mfa(mfa)
    end
  end

  defp request_impl(mfa, from, state) when is_map_key(state, mfa) do
    {:noreply, Map.put(state, mfa, [from])}
  end
  defp request_impl(mfa, from, state) do
    {:noreply, Map.put(state, mfa, [from, state[mfa]])}
  end

  @spec report(mfa, Type.Inference.Block.t) :: :ok
  def report(mfa = {module, _, _}, block) do
    # first stash it in the ETS table, then make sure that
    # everyone gets notified.  This prevents a gap period
    # where someone may make a request that gets unsatisfied.
    :ets.insert_new(__MODULE__, {mfa, block})
    :ets.insert(__MODULE__, {module, :done})
    GenServer.call(__MODULE__, {:report, mfa, block})
  end

  defp report_impl(mfa, block, _from, state) when is_map_key(state, mfa) do
    state
    |> Map.get(mfa)
    |> Enum.each(fn from ->
      GenServer.reply(from, block)
    end)
    {:reply, :ok, state}
  end
  defp report_impl(_, _, _, state), do: {:reply, :ok, state}

  ############################################################################
  # WORKERS

  def fetch_mfa(mfa = {module, fun, arity}) do
    module |> IO.inspect(label: "70")

    Type.Inference.Module.from_module(module)
    |> IO.inspect(label: "75")

    raise "foo"
  end

  ############################################################################
  # ROUTER

  def handle_call({:request, mfa}, from, state) do
    request_impl(mfa, from, state)
  end
  def handle_report({:report, mfa, block}, from, state) do
    report_impl(mfa, block, from, state)
  end
end
