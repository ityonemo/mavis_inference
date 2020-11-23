defmodule TypeTest.Opcode.JumpTest do

  # tests on the return opcode.
  use ExUnit.Case, async: true

  import TypeTest.OpcodeCase

  import Type

  alias Type.Inference.Application.BlockCache
  alias Type.Inference.Block.Parser
  alias Type.Inference.{Registers, Block}

  describe "jump opcode" do
    @op_jump [{:jump, {:f, 10}}]

    setup do
      BlockCache.preseed({__MODULE__, 10}, [%Block{
        needs: %{0 => builtin(:integer), 1 => builtin(:integer)},
        makes: builtin(:float)
      }])
      :ok
    end

    test "forward propagates jump target type" do
      state = @op_jump
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "backpropagates the needs types of the jump target" do
      state = @op_jump
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} =
        history_start(state)
    end

    test "warns on overbroad inputs"

    test "errors on incompatible inputs"
  end

end
