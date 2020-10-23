defmodule TypeTest.LabelTest do
  use ExUnit.Case, async: true

  alias Type.Function
  alias Type.Inference.Label

  import Type

  @moduletag :label

  test "some basic parser things" do
    assert %Function{params: [builtin(:any)], return: builtin(:any)}
      = Label.parse([:return])
  end
end
