defmodule Type.Engine.Api do
  @type opcode :: atom | tuple

  @callback forward(opcode, Type.Vm.t()) ::
              {:ok, Type.Vm.t()}
              | {:backprop, [Type.Vm.t()]}
              | :unknown
              
  @callback backprop(opcode, Type.Vm.t()) ::
              {:ok, [Type.Vm.t()]}
              | {:error, term}
              | :unknown
end
