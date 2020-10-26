defmodule TypeTest.Abstract.OpcodeMacroTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  # tests to make sure that compilation of opcode stuff with macros don't
  # cause warnings or errors.

  @unused_term_fwd_check """
  defmodule TypeTest.MTF1 do
    use Type.Inference.Macros

    opcode {:fwd_no, a} do
      forward(state, ...) do
        {:ok, state}
      end
      backprop(state, ...) do
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
    use Type.Inference.Macros

    opcode {:fwd_no, a} do
      forward(state = %{foo: a}, ...) do
        {:ok, state}
      end
      backprop(state, ...) do
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
    use Type.Inference.Macros

    opcode {:bck_no, a} do
      forward(state, ...) do
        IO.puts(a)
        {:ok, state}
      end
      backprop(state, ...) do
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
    use Type.Inference.Macros

    opcode {:bck_no, a} do
      forward(state, ...) do
        IO.puts(a)
        {:ok, state}
      end
      backprop(state = %{foo: a}, ...) do
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
