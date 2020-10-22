defmodule TypeTest.ModuleTest do
  use ExUnit.Case, async: true

  @moduletag :type_module

  alias Type.Function
  alias Type.Inference.Module

  import Type

  test "from_binary/1 produces the expected content" do
    {_, binary, _} = :code.get_object_code(TypeTest.ModuleExample)

    module = Module.from_binary(binary)

    assert %Module{
      label_blocks: blocks,
      entry_points: %{{:function, 1} => ep}
    } = module

    assert %{^ep => %Function{params: [builtin(:any)], return: builtin(:any)}}
      = blocks
  end
end
