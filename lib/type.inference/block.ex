defmodule Type.Inference.Block do
  @enforce_keys [:needs, :makes]
  defstruct @enforce_keys

  @type t :: [%__MODULE__{
    needs: %{optional(integer) => Type.t},
    makes: Type.t
  }]

  @type id :: {module, {atom, arity} | nil, :beam_asm.label}
  @type dep :: {module, :beam_asm.label} | mfa

  defdelegate parse(code, metadata \\ []), to: Type.Inference.Block.Parser

  import Type

  @spec to_function(t) :: Type.t
  def to_function(blocks) do
    blocks
    |> Enum.map(fn block ->
      %Type.Function{
        params: get_params(block),
        return: block.makes,
        inferred: true
      }
    end)
    |> Enum.into(%Type.Union{})
  end

  @spec from_spec(Type.Function.t | Type.Union.t) :: {:ok, [t]} | {:error, term}
  def from_spec(%Type.Function{params: p, return: r}) do
    needs = p
    |> Enum.with_index
    |> Enum.map(fn {t, i} -> {i, t} end)
    |> Enum.into(%{})

    {:ok, [%__MODULE__{needs: needs, makes: r}]}
  end
  def from_spec(%Type.Union{of: funs}) do
    {:ok, Enum.flat_map(funs, &(case from_spec(&1) do
      {:ok, [spec]} -> [spec]
      error = {:error, _} -> throw error
    end))}
  catch
    error -> error
  end
  def from_spec(_spec) do
    {:error, "invalid typespec"}
  end

  defp get_params(%{needs: needs}) when needs == %{}, do: []
  defp get_params(block) do
    max_key = block.needs
    |> Map.keys
    |> Enum.max

    for idx <- 0..max_key do
      if type = block.needs[idx], do: type, else: builtin(:any)
    end
  end
end
