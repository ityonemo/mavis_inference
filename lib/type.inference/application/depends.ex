defmodule Type.Inference.Application.Depends do

  alias Type.Inference.Block

  @pubsub Type.Inference.Dependency.PubSub

  @type worker_descriptor :: {{atom, arity} | nil, :beam_lib.label}
  @type client_descriptor :: mfa | {module, :beam_lib.label}

  @spec broadcast(module, worker_descriptor, Block.t) :: :ok

  def broadcast(module, {nil, label}, block) do
    dispatch({module, label}, block)
  end
  def broadcast(module, {{function, arity}, label}, block) do
    dispatch({module, function, arity}, block)
    broadcast(module, {nil, label}, block)
  end

  @spec dispatch(client_descriptor, Block.t) :: :ok
  defp dispatch(key, block) do
    Registry.dispatch(@pubsub, key, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:block, key, block})
    end)
  end

  @spec on(client_descriptor) :: Block.t
  def on(client_descriptor) do
    Registry.register(@pubsub, client_descriptor, [])
    receive do
      {:block, ^client_descriptor, block} -> block
    end
  end

end
