defmodule Type.Inference do
  
  import Type

  @behaviour Type.Inference.Api

  @impl true
  @spec infer(module, atom, arity) :: {:ok, Type.t} | {:error, any}
  def infer(module, fun, arity) do
    fa = {fun, arity}
    with {:module, _} <- Code.ensure_loaded(module),
         {^module, binary, _filepath} <- :code.get_object_code(module),
         {:ok, mod_struct} <- Type.Inference.Module.from_binary(binary),
         %{^fa => label} <- mod_struct.entry_points,
         %{^label => types} <- mod_struct.block_lookup do
      {:ok, Type.Inference.Block.to_function(types)}
    else
      :error ->
        # must tolerate in-memory modules
        :unknown
      error = {:error, _} -> error
    end
  end
end
