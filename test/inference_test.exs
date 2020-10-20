defmodule TypeTest.InferenceTest do

  use ExUnit.Case, async: true

  import Type

  alias TypeTest.FunctionProperties

  describe "type.of/1 assigns lambdas" do
    test "for a fun that isn't precompiled" do
      assert %Type.Function{params: [builtin(:any)], return: builtin(:any), inferred: false} == Type.of(&(&1))
    end

    test "for precompiled lambdas" do
      assert %Type.Function{params: [builtin(:any)], return: builtin(:any)} == Type.of(&TypeTest.LambdaExamples.identity/1)
      assert %Type.Function{params: [builtin(:any)], return: builtin(:any)} == Type.of(TypeTest.LambdaExamples.identity_fn)
    end

    test "a lambda with a move" do
      assert FunctionProperties.has_opcode?({TypeTest.LambdaExamples, :with_move, 2}, [:move])
      assert %Type.Function{params: [builtin(:any), builtin(:any)], return: builtin(:any)} == Type.of(&TypeTest.LambdaExamples.with_move/2)
    end

    test "a lambda that sets a value" do
      assert %Type.Function{params: [], return: 47} == Type.of(&TypeTest.LambdaExamples.forty_seven/0)
      assert %Type.Function{params: [], return: remote(String.t)} == Type.of(&TypeTest.LambdaExamples.forty_seven_str/0)
    end

    test "a lambda with a backpropagating function" do
      assert FunctionProperties.has_opcode?({TypeTest.LambdaExamples, :with_bitsize, 1}, [:gc_bif, :bit_size])
      assert %Type.Function{params: [%Type.Bitstring{size: 0, unit: 1}], return: builtin(:non_neg_integer)} == Type.of(&TypeTest.LambdaExamples.with_bitsize/1)
    end

    test "a lambda with a function with forking code" do
      assert FunctionProperties.has_opcode?({TypeTest.LambdaExamples, :with_add, 2}, [:gc_bif, :+])
      assert %Type.Function{params: [builtin(:any), builtin(:any)], return: builtin(:any)} == Type.of(&TypeTest.LambdaExamples.with_add/2)
    end
  end
end
