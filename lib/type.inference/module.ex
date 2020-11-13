#
#  alias Type.Inference.Module.ParallelParser
#
#  # utility functions
#  @spec lookup(t, atom, arity) :: Block.t
#  def lookup(module_struct, function, arity) do
#    entry_point = module_struct.entry_points[{function, arity}]
#    module_struct.block_lookup[entry_point]
#  end
#
#  @spec code(t, atom, arity) :: [opcode]
#  def code(module_struct, function, arity) do
#    entry_point = module_struct.entry_points[{function, arity}]
#    Enum.reduce(module_struct.code, nil, fn
#      {:label, ^entry_point}, nil -> []
#      {:label, past}, code when past > entry_point ->
#        throw {:code, Enum.reverse(code)}
#      term, list when is_list(list) -> [term | list]
#      _, acc -> acc
#    end)
#  catch
#    {:code, code} -> code
#  end
#end
#
