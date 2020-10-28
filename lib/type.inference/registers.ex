defmodule Type.Inference.Registers do
  @moduledoc """
  struct which represents the virtual machine
  """

  @enforce_keys [:module]
  defstruct @enforce_keys ++ [x: %{}, y: %{}]

  @type t :: %__MODULE__{
    module: module,
    x: %{integer => Type.t},
    y: %{integer => Type.t}
  }

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{x: x, y: y}, opts) do
      xreg = x
      |> Enum.map(fn {r, t} -> ["(x#{r}) ", to_doc(t, opts)] end)
      |> Enum.intersperse([" | "])
      |> Enum.flat_map(&Function.identity/1)
      yreg = y
      |> Enum.map(fn {r, t} -> ["(y#{r}) ", to_doc(t, opts)] end)
      |> Enum.intersperse([" | "])
      |> Enum.flat_map(&Function.identity/1)

      concat(["| "] ++ xreg ++ yreg ++ [" |"])
    end
  end
end
