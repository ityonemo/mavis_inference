defmodule Type.Inference.Opcodes.Terminal do

  import Type, only: :macros

  use Type.Inference.Macros

  opcode {:select_val, {:x, _from}, {:f, _fail}, {:list, _list}}, :noop
  #opcode {:select_val, {:x, _from}, {:f, _fail}, {:list, _list}}, :unimplemented

  opcode :return do
    forward(state = %{xreg: %{0 => _type}}, ...) do
      {:ok, state}
    end
    forward(state = %{xreg: %{}}, ...) do
      {:backprop, [put_reg(state, 0, builtin(:any))]}
    end

    backprop :terminal
  end

  opcode {:line, _}, :noop

  opcode {:func_info, _, _, _} do
    forward(state, ...) do
      {:ok, put_reg(state, 0, builtin(:none))}
    end

    backprop :terminal
  end
end
