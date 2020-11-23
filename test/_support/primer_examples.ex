defmodule TypeTest.PrimerExamples do
  # examples from: https://blog.erlang.org/a-brief-BEAM-primer/

  def sum_tail(list), do: sum_tail(list, 0)
  def sum_tail([head | tail], acc) do
    sum_tail(tail, head + acc)
  end
  def sum_tail([], acc), do: acc

  #def sum_body([head | tail]) do
  #  head + sum_body(tail)
  #end
  #def sum_body([]), do: 0
#
  #def create_tuple(term), do: {:hello, term}
#
  #defmodule External do
  #  def call, do: :ok
  #end
#
  #def exception do
  #  try do
  #    External.call()
  #  catch
  #    :example -> :hello
  #  end
  #end
#
  #def selective_receive(ref) do
  #  receive do
  #    {^ref, result} -> result
  #  end
  #end
end
