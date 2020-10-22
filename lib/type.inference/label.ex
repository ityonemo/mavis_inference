defmodule Type.Inference.Label do

  @spec parse([Type.Inference.Module.opcode]) :: Type.t
  def parse(code) do
    code |> IO.inspect(label: "6")
  end

end
