defmodule Type.Inference.Opcodes.Misc do

  use Type.Inference.Opcodes

  alias Type.Inference.Module.ParallelParser

  # LINE MARKER OPCODE
  opcode {:line, _}, :noop

  # NOOP OPCODES

  opcode {:allocate, _, _}, :noop

  opcode {:allocate_zero, _, _}, :noop

  opcode {:allocate_heap, _, _, _}, :noop

  opcode {:allocate_heap_zero, _, _, _}, :noop

  opcode {:init, _}, :noop

  opcode {:test_heap, _, _}, :noop

  opcode {:deallocate, _}, :noop

  opcode {:trim, _, _}, :noop

  opcode :send, :noop

  # TO BE VERIFIED
  opcode {:badmatch, _}, :noop

  opcode {:try, _, _}, :noop

  opcode {:try_end, _}, :noop

  opcode {:try_case, _}, :noop

  opcode {:loop_rec, _, _}, :noop

  opcode {:loop_rec_end, _}, :noop

  opcode {:case_end, _}, :noop

  opcode {:raise, _, _, _}, :noop

  opcode {:catch, _, _}, :noop

  opcode {:catch_end, _}, :noop

  opcode :build_stacktrace, :noop

  opcode {:recv_mark, _}, :noop
end
