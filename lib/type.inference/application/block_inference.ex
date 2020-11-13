defmodule Type.Inference.Application.BlockInference.Api do
  @callback run({module, :beam_asm.label | {atom, arity}, [Type.Inference.opcode]}) :: :ok
end
