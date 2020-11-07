defmodule TypeTest.Abstract.GuardTest do
  use ExUnit.Case, async: true
  import TypeTest.OpcodeCase

  use Type.Inference.Opcodes

  @moduletag :abstract

  alias Type.Inference.Block.Parser

  describe "an opcode with a forward guard" do
    opcode :fwd_guard do
      forward(regs, _meta, ...) when is_defined(regs, {:x, 0}) do
        {:ok, put_reg(regs, {:x, 0}, :defined)}
      end
      forward(regs, _meta, ...) do
        {:ok, put_reg(regs, {:x, 0}, :not_defined)}
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
      forward(regs, _meta, ...) do
        {:ok, regs}
      end

      backprop(regs, _meta, ...) when is_defined(regs, {:x, 0}) do
        {:ok, [put_reg(regs, {:x, 0}, :defined)]}
      end
      backprop(regs, _meta, ...) do
        {:ok, [put_reg(regs, {:x, 0}, :undefined)]}
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

  describe "a guard in the opcode" do
    opcode any_code, when: any_code in [:code_1, :code_2] do
      forward(regs, _meta, ...) do
        {:ok, put_reg(regs, {:x, 0}, any_code)}
      end
    end

    test "can use one of the opcodes" do
      assert %{x: %{0 => :code_1}} = [:code_1]
      |> Parser.new
      |> Parser.do_forward(__MODULE__)
      |> history_finish
    end

    test "can use the other opcode" do
      assert %{x: %{0 => :code_2}} = [:code_2]
      |> Parser.new
      |> Parser.do_forward(__MODULE__)
      |> history_finish
    end
  end

  describe "guards in both the opcode and a operation" do
    opcode {:both_guard, reg}, when: elem(reg, 0) == :x do
      forward(regs, _meta, ...) when is_defined(regs, reg) do
        {:ok, put_reg(regs, reg, :foo)}
      end
    end

    opcode {:both_guard, lit} do
      forward(regs, _meta, ...) do
        {:ok, put_reg(regs, {:x, 0}, fetch_type(regs, lit))}
      end
    end

    test "performs the first case correctly" do
      assert %{x: %{1 => :foo}} = [{:both_guard, {:x, 1}}]
      |> Parser.new(preload: %{1 => :bar})
      |> Parser.do_forward(__MODULE__)
      |> history_finish
    end

    test "performs the second case correctly" do
      assert %{x: %{0 => :bar}} = [{:both_guard, {:atom, :bar}}]
      |> Parser.new
      |> Parser.do_forward(__MODULE__)
      |> history_finish
    end
  end
end
