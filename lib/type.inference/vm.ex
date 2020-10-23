defmodule Type.Inference.Vm do
  @moduledoc """
  struct which represents the virtual machine
  """

  defstruct [
    xreg: %{},
    yreg: %{}
  ]

  @type t :: %__MODULE__{
    xreg: %{integer => Type.t},
    yreg: %{integer => Type.t}
  }

end
