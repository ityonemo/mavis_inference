defmodule TypeTest.Abstract.OpcodeMacroTest do
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
      forward(state, _meta, ...) do
        {:ok, state}
      end
      backprop(state, _meta, ...) do
        IO.puts(a)
        {:ok, [state]}
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
      forward(state = %{foo: a}, _meta, ...) do
        {:ok, state}
      end
      backprop(state, _meta, ...) do
        IO.puts(a)
        {:ok, [state]}
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
      forward(state, _meta, ...) do
        IO.puts(a)
        {:ok, state}
      end
      backprop(state, _meta, ...) do
        {:ok, [state]}
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
      forward(state, _meta, ...) do
        IO.puts(a)
        {:ok, state}
      end
      backprop(state = %{foo: a}, _meta, ...) do
        {:ok, [state]}
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
end
