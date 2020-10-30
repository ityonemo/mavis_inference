defmodule TypeTest.RemoteLookupExamples do

  # function that doesn't have a spec

  def no_spec(string), do: :erlang.bit_size(string)

  @spec simple_spec(integer) :: integer
  def simple_spec(x), do: x

  @spec multi_spec(atom) :: atom
  @spec multi_spec(integer) :: integer
  def multi_spec(x), do: x
end
