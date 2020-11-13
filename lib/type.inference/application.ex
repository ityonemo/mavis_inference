defmodule Type.Inference.Application do
  @moduledoc """
  Application Supervision Tree required to coordinate bits and pieces
  of the concurrent type analysis machinery.
  """

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor,
        name: Type.Inference.TaskSupervisor,
        strategy: :one_for_one},
      {Registry,
        keys: :duplicate,
        name: Type.Inference.Dependency.PubSub},
      {Registry,
        keys: :unique,
        name: Type.Inference.ModuleTracker},
      Type.Inference.BlockCache
    ]

    opts = [strategy: :one_for_one, name: Type.Inference.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
