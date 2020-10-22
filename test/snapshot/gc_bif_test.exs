defmodule TypeTest.Snapshot.GcBifTest do
  use ExUnit.Case, async: true

  @gc_bif_plus [
    {:line, 1},
    {:label, 7},
    {:func_info, {:atom, TestCodeError}, {:atom, :function}, 1},
    {:label, 8},
    {:line, 2},
    {:gc_bif, :+, {:f, 0}, 1, [x: 0, literal: "foo"], {:x, 0}},
    :return
  ]

  test "+/foo" do
    raise "hell"
  end
end
