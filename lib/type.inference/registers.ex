defmodule Type.Inference.Registers do
  @moduledoc """
  struct which represents register tracking in the virtual machine
  """

  defstruct [x: %{}, y: %{}, freeze: nil]

  @type t :: %__MODULE__{
    x: %{integer => Type.t},
    y: %{integer => Type.t},
    freeze: nil | non_neg_integer
  }

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(registers, opts) do
      xreg = registers.x
      |> Enum.map(fn {r, t} -> ["(x#{r}) ", to_doc(t, opts)] end)
      |> Enum.intersperse([" : "])
      |> Enum.flat_map(&Function.identity/1)
      yreg = registers.y
      |> Enum.map(fn {r, t} -> ["(y#{r}) ", to_doc(t, opts)] end)
      |> Enum.intersperse([" : "])
      |> Enum.flat_map(&Function.identity/1)

      freeze = if registers.freeze, do: "(frozen)", else: ""

      concat(["#Reg", freeze, "<"] ++ xreg ++ yreg ++ [">"])
    end
  end
end
