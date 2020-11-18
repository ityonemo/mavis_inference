defmodule Type.Engine.Api do
  @type opcode :: atom | tuple

  alias Type.Registers

  @callback forward(opcode, meta :: map, Registers.t) ::
              {:ok, Registers.t}
              | {:ok, [Registers.t]}
              | {:freeze, Registers.t}
              | {:backprop, [Registers.t]}
              | :unknown

  @callback backprop(opcode, meta :: map, Registers.t) ::
              {:ok, Registers.t}
              | {:ok, [Registers.t]}
              | {:error, term}
              | :unknown
end
