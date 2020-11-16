defmodule Type.Inference.Application.BlockAnalyzer.Api do
  @callback run({module,
                 {atom, arity} | nil,
                 :beam_asm.label},
                 [Type.Inference.opcode]) :: :ok
end

defmodule Type.Inference.Application.BlockAnalyzer do

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block.Parser

  def run(block_id, code, parser_module \\ Parser) do
    Task.Supervisor.start_child(Type.Inference.TaskSupervisor, fn ->
      task(block_id, code, parser_module)
    end)
  end

  defp task(block_id, code, parser_module) do
    # preflight chores for task
    # stash information about who we are in the Process dictionary
    Process.put(:block_id, block_id)
    infer(block_id, code, parser_module)
  end

  defp infer(block_id, code, parser_module) do
    # broadcast completion of the block when we are done analyzing it.
    block = parser_module.parse(code, module: elem(block_id, 0))

    BlockCache.resolve(block_id, block)
  end
end
