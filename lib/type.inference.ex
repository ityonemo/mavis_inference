defmodule Type.Inference do

  @behaviour Type.Inference.Api

  @type opcode :: atom | tuple

  @type functions :: Type.Function.t | Type.Union.t(Type.Function.t)

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block

  @impl true
  @spec infer(module, atom, arity) :: {:ok, functions} | {:error, any}
  def infer(module, fun, arity) do
    with {:module, _} <- Code.ensure_loaded(module),
         {^module, _binary, _filepath} <- :code.get_object_code(module) do

      function = {module, fun, arity}
      |> BlockCache.depend_on
      |> Block.to_function

      {:ok, function}
    else
      :error ->
        # must tolerate in-memory modules
        :unknown
      error = {:error, _} -> error
    end
  end
end

defmodule Type.InferenceError do
  defexception [:message]
end
