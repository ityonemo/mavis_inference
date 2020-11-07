defmodule TypeTest.Abstract.OpcodeGuardTest do
  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  import ExUnit.CaptureIO

  use Type.Inference.Opcodes, debug_dump_code: true

  @moduletag :abstract

  alias Type.Inference.Block.Parser

  import Type

  describe "an opcode with a forward guard" do
    opcode :fwd_guard do
      forward(state, _meta, ...) when is_defined(state, {:x, 0}) do
        {:ok, put_reg(state, {:x, 0}, :defined)}
      end
      forward(state, _meta, ...) do
        {:ok, put_reg(state, {:x, 0}, :not_defined)}
      end
    end

    test "falls through first condition" do
      assert %{x: %{0 => :defined}} = [:fwd_guard]
      |> Parser.new(preload: %{0 => :foo})
      |> Parser.do_forward(__MODULE__)
      |> history_finish
    end

    test "falls through second condition" do
      assert %{x: %{0 => :not_defined}} = [:fwd_guard]
      |> Parser.new
      |> Parser.do_forward(__MODULE__)
      |> history_finish
    end
  end

  describe "an opcode with a backprop guard" do
    opcode :bck_guard do
      forward(state, _meta, ...) do
        {:ok, state}
      end

      backprop(state, _meta, ...) when is_defined(state, {:x, 0}) do
        {:ok, [put_reg(state, {:x, 0}, :defined)]}
      end
      backprop(state, _meta, ...) do
        {:ok, [put_reg(state, {:x, 0}, :undefined)]}
      end
    end

    test "falls through first condition" do
      assert %{x: %{0 => :defined}} = [:bck_guard]
      |> Parser.new(preload: %{0 => :foo})
      |> Parser.do_forward(__MODULE__)
      |> Parser.do_backprop(__MODULE__)
      |> history_start
    end

    test "falls through second condition" do
      assert %{x: %{0 => :undefined}} = [:bck_guard]
      |> Parser.new()
      |> Parser.do_forward(__MODULE__)
      |> Parser.do_backprop(__MODULE__)
      |> history_start
    end
  end
end
