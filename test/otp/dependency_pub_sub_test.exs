defmodule TypeTest.Inference.OTP.DependencyPubSubTest do
  # tests that the OTP pubsub parts work.

  use ExUnit.Case, async: true

  alias Type.Inference.Application.Depends

  @test_block %Type.Inference.Block{
    needs: %{}, makes: %Type{name: :any}
  }

  describe "pubsub allows you to register" do
    test "a dependency by MFA" do
      future = Task.async(fn ->
        Depends.on({MyModule, :my_func, 0})
      end)

      Process.sleep(100)

      Depends.broadcast(MyModule, {{:my_func, 0}, 15}, @test_block)

      assert @test_block = Task.await(future)
    end

    test "a dependency by module/block number" do
      future = Task.async(fn ->
        Depends.on({MyModule, 15})
      end)

      Process.sleep(100)

      Depends.broadcast(MyModule, {{:my_func, 0}, 15}, @test_block)

      assert @test_block = Task.await(future)
    end
  end

end
