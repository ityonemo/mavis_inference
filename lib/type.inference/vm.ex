defmodule Type.Inference.Vm do
  @moduledoc """
  struct which represents the virtual machine
  """

  @enforce_keys [:module]
  defstruct @enforce_keys ++ [
    xreg: %{},
    yreg: %{}
  ]

  @type t :: %__MODULE__{
    module: module,
    xreg: %{integer => Type.t},
    yreg: %{integer => Type.t}
  }

end
