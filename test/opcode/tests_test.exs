defmodule TypeTest.Opcode.TestsTest do

  #tests on the {:test, x...} opcodes

  use ExUnit.Case, async: true
  use Type.Operators
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Registers
  alias Type.Inference.Application.BlockCache

  @op_set0 {:move, {:atom, :foo}, {:x, 0}}

  setup do
    BlockCache.preseed({__MODULE__, 10}, [%Block{
      needs: %{0 => builtin(:integer)},
      makes: builtin(:float)
    }])

    # also preseed a value that can have multiple choices
    BlockCache.preseed({__MODULE__, 99}, [%Block{
      needs: %{0 => builtin(:integer)},
      makes: builtin(:float)
    }, %Block{
      needs: %{0 => builtin(:atom)},
      makes: :foo
    }])
    :ok
  end

  describe "is_integer opcode" do
    @op_is_int {:test, :is_integer, {:f, 11}, [x: 0]}
    @op_is_int_all [@op_is_int, @op_set0]

    @default_atom_block [%Block{
      needs: %{0 => builtin(:atom)},
      makes: builtin(:float)
    }]

    setup do
      BlockCache.preseed({__MODULE__, 11}, @default_atom_block)
      :ok
    end

    test "forward propagates the type on an integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on pos_integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:pos_integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on neg_integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:neg_integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on non_neg_integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:non_neg_integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on literal integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => 47}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:atom)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_int_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end


  describe "is_nil opcode" do
    @op_is_nil {:test, :is_nil, {:f, 10}, [x: 0]}
    @op_is_nil_all [@op_is_nil, @op_set0]

    test "forward propagates the type on nil" do
      state = @op_is_nil_all
      |> Parser.new(preload: %{0 => nil}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => nil}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_nil_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "triggers backprop when there's nothing in the test register" do
      state = @op_is_nil_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => nil}} = history_start(state, 0)
      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)

      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"

    @op_is_nil_bifurc {:test, :is_nil, {:f, 99}, [x: 0]}
    test "performs a backpropagation" do
      state = [@op_is_nil_bifurc]
      |> Parser.new(module: __MODULE__)
      |> Parser.do_forward |> IO.inspect(label: "168")
      |> change_final(0, :foo)
      |> change_final(1, :foo)
      |> IO.inspect(label: "159")
    end
  end

  describe "is_boolean opcode" do
    @op_is_bool {:test, :is_boolean, {:f, 10}, [x: 0]}
    @op_is_bool_all [@op_is_bool, @op_set0]

    test "forward propagates the type on true" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => true}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => true}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on false" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => false}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => false}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on boolean" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => builtin(:boolean)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:boolean)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_bool_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:boolean)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_atom opcode" do
    @op_is_atom {:test, :is_atom, {:f, 10}, [x: 0]}
    @op_is_atom_all [@op_is_atom, @op_set0]

    test "forward propagates the type on arbitrary atom" do
      state = @op_is_atom_all
      |> Parser.new(preload: %{0 => :quux}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :quux}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on builtin atom" do
      state = @op_is_atom_all
      |> Parser.new(preload: %{0 => builtin(:atom)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_atom_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_atom_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_tuple opcode" do
    @op_is_tup {:test, :is_tuple, {:f, 10}, [x: 0]}
    @op_is_tup_all [@op_is_tup, @op_set0]

    test "forward propagates the type on an any tuple" do
      state = @op_is_tup_all
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: {:min, 0}}}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: {:min, 0}}}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on an a defined tuple" do
      state = @op_is_tup_all
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: [builtin(:any)]}}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: [builtin(:any)]}}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_tup_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_tup_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: {:min, 0}}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_tagged_tuple opcode" do
    @op_is_ttup {:test, :is_tagged_tuple, {:f, 10}, [{:x, 0}, 2, {:atom, :tag}]}
    @op_is_ttup_all [@op_is_ttup, @op_set0]

    test "forward propagates the type on an any tuple" do
      state = @op_is_ttup_all
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: [:tag, builtin(:any)]}}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_ttup_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_ttup_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: [:tag, builtin(:any)]}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_port opcode" do
    @op_is_port {:test, :is_port, {:f, 10}, [x: 0]}
    @op_is_port_all [@op_is_port, @op_set0]

    test "forward propagates the type on a general list" do
      assert %{x: %{0 => :foo}} = @op_is_port_all
      |> Parser.new(preload: %{0 => builtin(:port)}, module: __MODULE__)
      |> fast_forward()
      |> history_final
    end

    test "forward propagates the type that matches the jump condition" do
      assert %{x: %{0 => builtin(:float)}} = @op_is_port_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward
      |> history_final
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_port_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %{x: %{0 => builtin(:port)}} = history_start(state, 0)
      assert %{x: %{0 => :foo}} = history_final(state, 0)

      assert %{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_reference opcode" do
    @op_is_ref {:test, :is_reference, {:f, 10}, [x: 0]}
    @op_is_ref_all [@op_is_ref, @op_set0]
    @binary %Type.Bitstring{unit: 8}

    test "forward propagates the type on a general list" do
      assert %{x: %{0 => :foo}} = @op_is_ref_all
      |> Parser.new(preload: %{0 => builtin(:reference)}, module: __MODULE__)
      |> fast_forward()
      |> history_final
    end

    test "forward propagates the type that matches the jump condition" do
      assert %{x: %{0 => builtin(:float)}} = @op_is_ref_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward
      |> history_final
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_ref_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %{x: %{0 => builtin(:reference)}} = history_start(state, 0)
      assert %{x: %{0 => :foo}} = history_final(state, 0)

      assert %{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end


  describe "is_list opcode" do
    @op_is_lst {:test, :is_list, {:f, 10}, [x: 0]}
    @op_is_lst_all [@op_is_lst, @op_set0]
    @any_list %Type.List{type: builtin(:any)}

    test "forward propagates the type on a general list" do
      state = @op_is_lst_all
      |> Parser.new(preload: %{0 => @any_list}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => @any_list}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type on a list with any final" do
      state = @op_is_lst_all
      |> Parser.new(preload: %{0 => %Type.List{type: builtin(:any), final: builtin(:any)}}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.List{type: builtin(:any), final: builtin(:any)}}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_lst_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_lst_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.List{type: builtin(:any), final: builtin(:any)}}}
        = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_binary opcode" do
    @op_is_bin {:test, :is_binary, {:f, 10}, [x: 0]}
    @op_is_bin_all [@op_is_bin, @op_set0]
    @binary %Type.Bitstring{unit: 8}

    test "forward propagates the type on a general list" do
      assert %{x: %{0 => :foo}} = @op_is_bin_all
      |> Parser.new(preload: %{0 => @binary}, module: __MODULE__)
      |> fast_forward()
      |> history_final
    end

    test "forward propagates the type that matches the jump condition" do
      assert %{x: %{0 => builtin(:float)}} = @op_is_bin_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward
      |> history_final
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_bin_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %{x: %{0 => @binary}} = history_start(state, 0)
      assert %{x: %{0 => :foo}} = history_final(state, 0)

      assert %{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  @function_1 %Type.Function{params: [builtin(:any)], return: builtin(:any)}

  describe "is_function opcode" do
    @op_is_fun {:test, :is_function, {:f, 10}, [x: 0]}
    @op_is_fun_all [@op_is_fun, @op_set0]

    test "forward propagates the type on a function" do
      state = @op_is_fun_all
      |> Parser.new(preload: %{0 => @function_1}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => @function_1}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_fun_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_fun_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Function{params: :any, return: builtin(:any)}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_function2 opcode with constant integer" do
    @op_is_f2_1 {:test, :is_function2, {:f, 10}, [x: 0, integer: 1]}
    @op_is_f2_1_all [@op_is_f2_1, @op_set0]

    test "forward propagates the type on correct-arity function" do
      state = @op_is_f2_1_all
      |> Parser.new(preload: %{0 => @function_1}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => @function_1}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_f2_1_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_f2_1_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Function{params: [builtin(:any)], return: builtin(:any)}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_function2 opcode with param integer" do
    test "works"
  end

  test "reorganize this along the lines of type order"

  describe "is_map opcode" do
    @op_is_map {:test, :is_map, {:f, 10}, [x: 0]}
    @op_is_map_all [@op_is_map, @op_set0]
    @any_map %Type.Map{optional: %{builtin(:any) => builtin(:any)}}

    test "forward propagates the type on a map" do
      state = @op_is_map_all
      |> Parser.new(preload: %{0 => @any_map}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => @any_map}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_map_all
      |> Parser.new(preload: %{0 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_map_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => @any_map}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  test "make is_eq_exact operate on arbitrary types of things"

  describe "is_eq_exact opcode" do
    @op_is_eq_exact {:test, :is_eq_exact, {:f, 10}, [x: 0, x: 1]}
    @op_is_eq_exact_all [@op_is_eq_exact, @op_set0]

    test "forward propagates both types when types match" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "forward propagates only the success type when it's a matching singleton type" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => :bar, 1 => :bar}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => :bar, 1 => :bar}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
      assert length(state.histories) == 1
    end

    test "forward propagates only the failure type when it's a mismatching singleton type" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => 1, 1 => 2}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => 1, 1 => 2}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
      assert length(state.histories) == 1
    end

    test "forward propagates the jump type if it's a mismatch" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:float)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:float)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates any() when content is missing for either register" do
      state = @op_is_eq_exact_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 0)
      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_lt opcode" do
    @op_is_lt {:test, :is_lt, {:f, 10}, [x: 0, x: 1]}
    @op_is_lt_all [@op_is_lt, @op_set0]

    test "forward propagates both always" do
      state = @op_is_lt_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:pid)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:pid)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:pid)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates any() when content is missing for either register" do
      state = @op_is_lt_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 0)
      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_ne opcode" do
    @op_is_ne {:test, :is_ne, {:f, 10}, [x: 0, x: 1]}
    @op_is_ne_all [@op_is_ne, @op_set0]

    test "forward propagates when both types when types match" do
      state = @op_is_ne_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:integer)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_final(state, 0)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state, 1)
    end

    test "forward propagates only the fail type when it's a matching singleton type" do
      state = @op_is_ne_all
      |> Parser.new(preload: %{0 => 1, 1 => 1}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => 1, 1 => 1}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_final(state)
      assert length(state.histories) == 1
    end

    test "forward propagate fails when the matching singleton does not clear the fail jump"

    test "forward propagates the jump type if it's a mismatch" do
      state = @op_is_ne_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:atom)}, module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:atom)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_final(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates any() when content is missing for either register" do
      state = @op_is_ne_all
      |> Parser.new(module: __MODULE__)
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 0)
      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 1)
    end

    test "passes needs through a backpropagation"
  end
end
