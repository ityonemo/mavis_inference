defmodule Type.Inference.Opcodes.Misc do

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  # LINE MARKER OPCODE
  opcode {:line, _}, :noop

  # NOOP OPCODES

  opcode {:allocate, _, _}, :noop

  opcode {:allocate_zero, _, _}, :noop

  opcode {:allocate_heap, _, _, _}, :noop

  opcode {:init, _}, :noop

  opcode {:test_heap, _, _}, :noop

  opcode {:deallocate, _}, :noop

  opcode {:trim, _, _}, :noop

  # TO BE VERIFIED
  opcode {:badmatch, _}, :noop

  opcode {:try_case, _}, :noop

  opcode {:case_end, _}, :noop

end
