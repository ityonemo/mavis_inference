defmodule Type.Inference.Application.BlockAnalyzer.Api do
  @callback run({module,
                 {atom, arity} | nil,
                 :beam_asm.label,
                 [Type.Inference.opcode]}) :: :ok
end

defmodule Type.Inference.Application.BlockAnalyzer do

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block.Parser

  def run(block_spec, parser_module \\ Parser) do
    Task.Supervisor.start_child(Type.Inference.TaskSupervisor, fn ->
      task(block_spec, parser_module)
    end)
  end

  defp task(block_spec, parser_module) do
    # preflight chores for task
    # stash information about who we are in the Process dictionary
    Process.put(:block_spec, block_spec)
    infer(block_spec, parser_module)
  end

  defp infer({module, fa, label, code}, parser_module) do

    # broadcast completion of the block when we are done analyzing it.
    block = parser_module.parse(code)

    BlockCache.resolve({module, fa, label}, block)
  end
end
