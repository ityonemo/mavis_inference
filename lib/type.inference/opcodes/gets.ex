defmodule Type.Inference.Opcodes.Gets do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  opcode {:get_tuple_element, from, index, to} do
    forward(state, _meta, ...) do
      case fetch_type(state, from) do
        %Type.Tuple{elements: els} when length(els) > index ->
          {:ok, put_reg(state, to, Enum.at(els, index))}
        _ -> {:error, "foobar"}
      end
    end

    backprop :terminal
  end

end
