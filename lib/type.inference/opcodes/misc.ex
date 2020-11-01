defmodule Type.Inference.Opcodes.Misc do

  use Type.Inference.Macros

  opcode {:line, _}, :noop

  opcode {:allocate, _, _}, :noop

  opcode {:allocate_zero, _, _}, :noop

  opcode {:init, _}, :noop

  opcode {:test_heap, _, _}, :noop
end
