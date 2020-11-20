defmodule TypeTest.OpcodeCase do

  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers

  @spec fast_forward(Parser.t, module) :: Parser.t
  def fast_forward(state, module \\ nil)
  def fast_forward(state = %{code: []}, _module), do: state
  def fast_forward(state, module) do
    state
    |> Parser.do_forward(module)
    |> Parser.log_forward
    |> fast_forward(module)
  end

  @spec history_start(Parser.t, non_neg_integer) :: Registers.t
  def history_start(state, index \\ 0) do
    state.histories
    |> Enum.at(index)
    |> List.last
  end

  @spec history_final(Parser.t, non_neg_integer) :: Registers.t
  def history_final(state, index \\ 0) do
    state.histories
    |> Enum.at(index)
    |> List.first
  end

  @spec change_final(Parser.t, non_neg_integer, Type.t, non_neg_integer) :: Parser.t
  def change_final(state, register, type, index \\ 0) do
    new_histories = state.histories
    |> Enum.with_index
    |> Enum.map(fn
      {[latest | rest], ^index} ->
        [%{latest | x: Map.put(latest.x, register, type)} | rest]
      {history, _} -> history
    end)

    %{state | histories: new_histories}
  end

end
