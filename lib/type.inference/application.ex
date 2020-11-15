defmodule Type.Inference.Application do
  @moduledoc """
  Application Supervision Tree required to coordinate bits and pieces
  of the concurrent type analysis machinery.
  """

  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor,
        name: Type.Inference.TaskSupervisor},
      {Registry,
        keys: :duplicate,
        name: Type.Inference.Dependency.PubSub},
      {Registry,
        keys: :unique,
        name: Type.Inference.ModuleTracker},
      Type.Inference.Application.BlockCache
    ]

    opts = [strategy: :one_for_one, name: Type.Inference.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
