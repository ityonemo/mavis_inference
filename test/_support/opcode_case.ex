defmodule TypeTest.OpcodeCase do

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  @spec fast_forward(Parser.t) :: Parser.t
  def fast_forward(state = %{code: []}), do: state
  def fast_forward(state) do
    state
    |> Parser.do_forward
    |> fast_forward
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
