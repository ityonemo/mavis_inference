defmodule Type.Inference.Opcodes.Misc do

  import Type, only: :macros

  use Type.Inference.Macros

  opcode {:line, _}, :noop

end
