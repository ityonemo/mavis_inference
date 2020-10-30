defmodule Type.Inference.RemoteLookup do
  # TODO: make this conform to the "inference" MFA
  # TODO: turn this into a property that can be controlled by configuration
  # variable.

  @moduledoc """
  this module is just a shim that lets us do some early testing with modules
  and stuff.  It will probably be replaced by a more sophisticated module,
  especially, when deployed for example in Selectrix.
  """

  alias Type.Inference.Block

  def infer(module, fun, arity) do
    case Type.fetch_spec(module, fun, arity) do
      {:ok, spec} -> Block.from_spec(spec)
      {:error, _} ->
        if function_exported?(module, fun, arity) do
          Type.Inference.infer(module, fun, arity)
        else
          {:error, "function not found"}
        end
    end
  end

end
