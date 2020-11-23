defmodule TypeTest.Abstract.ComptimeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @completely_empty_opcode_module """
  defmodule TypeTest.EOM do
    use Type.Inference.Opcodes
  end
  """

  setup_all do
    [{module, _}] = Code.compile_string(@completely_empty_opcode_module)

    {:ok, module: module}
  end

  describe "a completely empty opcode module" do
    test "can still be called with forward", %{module: module} do
      assert :unknown == module.forward(:foo, %{}, %{})
    end

    test "can still be called with backprop", %{module: module} do
      assert :unknown == module.forward(:foo, %{}, %{})
    end
  end

  # tests to make sure that compilation of opcode stuff with macros don't
  # cause warnings or errors.

  @unused_term_fwd_check """
  defmodule TypeTest.MTF1 do
    use Type.Inference.Opcodes

    opcode {:fwd_no, a} do
      forward(regs, _meta, ...) do
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) do
        IO.puts(a)
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is not used in forward, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_fwd_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_fwd_match_check """
  defmodule TypeTest.MTF2 do
    use Type.Inference.Opcodes

    opcode {:fwd_no, a} do
      forward(regs = %{foo: a}, _meta, ...) do
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) do
        IO.puts(a)
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is used in the forward match, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_fwd_match_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_bck_check """
  defmodule TypeTest.MTB1 do
    use Type.Inference.Opcodes

    opcode {:bck_no, a} do
      forward(regs, _meta, ...) do
        IO.puts(a)
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) do
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is not used in backprop, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_bck_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_bck_match_check """
  defmodule TypeTest.MTB2 do
    use Type.Inference.Opcodes

    opcode {:bck_no, a} do
      forward(regs, _meta, ...) do
        IO.puts(a)
        {:ok, regs}
      end
      backprop(out_regs = %{foo: a}, _in_regs, _meta, ...) do
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is used in the backprop match, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_bck_match_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_guard_check """
  defmodule TypeTest.MTF2 do
    use Type.Inference.Opcodes

    opcode {:guard_no, a}, when: is_integer(a) do
      forward(regs, _meta, ...) do
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) do
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is used in the guard, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_guard_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_fwd_guard_check """
  defmodule TypeTest.MTF2 do
    use Type.Inference.Opcodes

    opcode {:fwd_guard_no, a} do
      forward(regs, _meta, ...) when is_defined(regs, a) do
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) do
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is used in a forward guard, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_fwd_guard_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_bck_guard_check """
  defmodule TypeTest.MTF2 do
    use Type.Inference.Opcodes

    opcode {:bck_guard_no, a} do
      forward(regs, _meta, ...) do
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) when is_defined(out_regs, a) do
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is used in a backprop guard, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_bck_guard_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_dupe_check """
  defmodule TypeTest.MTF2 do
    use Type.Inference.Opcodes

    opcode {:dupe_no, a, a} do
      forward(regs, _meta, ...) do
        {:ok, regs}
      end
      backprop(out_regs, _in_regs, _meta, ...) do
        {:ok, out_regs}
      end
    end
  end
  """

  test "if an opcode match is duplicated in the opcode, it doesn't cause warning" do
    warnings = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_dupe_check)
    end)

    refute warnings =~ "is unused"
  end

  @unused_term_regression_check """
  defmodule TypeTest.Reg0 do
    use Type.Inference.Opcodes

    opcode {:gc_bif, :length, _fail, _, [from], to} do
      forward(regs, _meta, ...) when not is_defined(regs, from) do
        {:backprop, [put_reg(regs, from, %Type.List{})]}
      end

      forward(regs, _meta, ...) when is_reg(regs, from, []) do
        {:ok, put_reg(regs, to, 0)}
      end

      forward(regs, _meta, ...) do
        cond do
          match?(%Type.List{nonempty: true}, get_reg(regs, from)) ->
            {:ok, put_reg(regs, to, builtin(:pos_integer))}
          match?(%Type.List{}, get_reg(regs, from)) ->
            {:ok, put_reg(regs, to, builtin(:non_neg_integer))}
        end
      end

      backprop :terminal
    end
  end
  """

  test "opcode warning regression test" do
    warning = (capture_io :stderr, fn ->
      Code.compile_string(@unused_term_regression_check)
    end)

    refute warning =~ "is unused"
  end
end
