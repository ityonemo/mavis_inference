defmodule TypeTest.Inference.OTP.DependencyPubSubTest do
  # tests that the OTP pubsub parts work.

  use ExUnit.Case, async: true

  alias Type.Inference.Application.BlockCache

  @test_block %Type.Inference.Block{
    needs: %{}, makes: %Type{name: :any}
  }

  describe "pubsub allows you to register" do
    test "a dependency by MFA" do
      future = Task.async(fn ->
        BlockCache.depend_on({MyModule, :my_func, 0})
      end)

      Process.sleep(100)

      BlockCache.broadcast({MyModule, {:my_func, 0}, 15}, @test_block)

      assert @test_block = Task.await(future)
    end

    test "a dependency by module/block number" do
      future = Task.async(fn ->
        BlockCache.depend_on({MyModule, 15})
      end)

      Process.sleep(100)

      BlockCache.broadcast({MyModule, {:my_func, 0}, 15}, @test_block)

      assert @test_block = Task.await(future)
    end
  end

end
