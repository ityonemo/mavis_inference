defmodule Type.Inference.Debug do
  
  import Record
  defrecord :beam_file, Record.extract(:beam_file, from_lib: "compiler/src/beam_disasm.hrl")

  def dump_module(module) do
    {:module, _} = Code.ensure_loaded(module)
    {^module, binary, _filepath} = :code.get_object_code(module)
    beam_file(module: ^module, code: code) = :beam_disasm.file(binary)

    code
  end
end
