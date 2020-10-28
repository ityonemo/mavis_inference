defmodule Type.Engine.Api do
  @type opcode :: atom | tuple

  @callback forward(opcode, meta :: map, Type.Registers.t()) ::
              {:ok, Type.Registers.t()}
              | {:backprop, [Type.Registers.t()]}
              | :unknown

  @callback backprop(opcode, meta :: map, Type.Registers.t()) ::
              {:ok, [Type.Registers.t()]}
              | {:error, term}
              | :unknown
end
