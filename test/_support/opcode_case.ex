defmodule TypeTest.OpcodeCase do

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  @spec fast_forward(Parser.t, module) :: Parser.t
  def fast_forward(state, module \\ nil)
  def fast_forward(state = %{code: []}, _module), do: state
  def fast_forward(state, module) do
    state
    |> Parser.do_forward(module)
    |> fast_forward(module)
  end

  @spec history_start(Parser.t, non_neg_integer) :: Registers.t
  def history_start(state, index \\ 0) do
    state.histories
    |> Enum.at(index)
    |> List.last
  end

  @spec history_finish(Parser.t, non_neg_integer) :: Registers.t
  def history_finish(state, index \\ 0) do
    state.histories
    |> Enum.at(index)
    |> List.first
  end

end
