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

  alias Type.Inference.Registers
  @spec eval(t, Registers.t) :: Type.t
  @doc """
  evaluates a type given a register
  """
  def eval(block, regs) do
    transpose_needs(block)
    |> Enum.map(fn {reg, block_types} ->
      {:ok, reg_type} = Map.fetch(regs.x, reg)

      reg_type
      |> Type.partition(block_types)
      |> Enum.map(&(&1 != builtin(:none)))
      |> Enum.all?
    end)
    |> Enum.with_index
    |> Enum.flat_map(fn
      {false, _index} -> []
      {true, index} -> [Enum.at(block, index).makes]
    end)
    |> Type.union
  end

  @spec transpose_needs(t) :: %{optional(non_neg_integer) => [Type.t]}
  @doc false
  # this function is a private function, made public only for testing
  # purposes.
  #
  # takes a "needs" definition and converts it into a map of registers
  # + list of types.  Each "needs" type list is a partitioning set; and
  # so each register value must have the same list length across all.
  #
  # In the future, this may get converted to the main representation
  # for the block spec.
  def transpose_needs(block) do
    block
    |> Enum.with_index
    |> Enum.reduce(%{}, fn {block_seg, index}, needs ->
      # transform a list of needs into a needs of lists
      block_seg.needs
      |> Enum.reduce(%{}, fn {reg, type}, acc ->
        if is_map_key(acc, reg) or index == 0 do
          Map.put(acc, reg, [type | List.wrap(needs[reg])])
        else
          Map.put(acc, reg, List.duplicate(builtin(:any), index))
        end
      end)
    end)
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
