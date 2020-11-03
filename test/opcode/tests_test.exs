defmodule TypeTest.Opcode.TestsTest do

  #tests on the {:test, x...} opcodes

  use ExUnit.Case, async: true
  use Type.Operators
  import TypeTest.OpcodeCase

  @moduletag :opcodes

  import Type, only: :macros

  alias Type.Inference.Block
  alias Type.Inference.Block.Parser
  alias Type.Inference.Module.ParallelParser
  alias Type.Inference.Registers

  @op_set0 {:move, {:atom, :foo}, {:x, 0}}

  setup do
    # preseed the test thread with a message containing the block
    # that's going to drop in.
    ParallelParser.send_lookup(self(), 10, :fun, 0, [%Block{
      needs: %{0 => builtin(:integer)},
      makes: builtin(:float)
    }])
  end

  describe "is_integer opcode" do
    @op_is_int {:test, :is_integer, {:f, 11}, [x: 0]}
    @op_is_int_all [@op_is_int, @op_set0]

    setup do
      # preseed the test thread with a message containing the block
      # that's going to drop in.
      ParallelParser.send_lookup(self(), 11, :fun, 0, [%Block{
        needs: %{0 => builtin(:atom)},
        makes: builtin(:float)
      }])
    end

    test "forward propagates the type on an integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on pos_integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:pos_integer)})
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on neg_integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:neg_integer)})
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on non_neg_integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:non_neg_integer)})
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on literal integer" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => 47})
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_int_all
      |> Parser.new(preload: %{0 => builtin(:atom)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_int_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end


  describe "is_nil opcode" do
    @op_is_nil {:test, :is_nil, {:f, 10}, [x: 0]}
    @op_is_nil_all [@op_is_nil, @op_set0]

    test "forward propagates the type on nil" do
      state = @op_is_nil_all
      |> Parser.new(preload: %{0 => nil})
      |> fast_forward

      assert %Registers{x: %{0 => nil}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_nil_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_nil_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => nil}} = history_start(state, 0)
      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)

      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_boolean opcode" do
    @op_is_bool {:test, :is_boolean, {:f, 10}, [x: 0]}
    @op_is_bool_all [@op_is_bool, @op_set0]

    test "forward propagates the type on true" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => true})
      |> fast_forward

      assert %Registers{x: %{0 => true}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on false" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => false})
      |> fast_forward

      assert %Registers{x: %{0 => false}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on boolean" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => builtin(:boolean)})
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:boolean)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_bool_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_bool_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:boolean)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_atom opcode" do
    @op_is_atom {:test, :is_atom, {:f, 10}, [x: 0]}
    @op_is_atom_all [@op_is_atom, @op_set0]

    test "forward propagates the type on arbitrary atom" do
      state = @op_is_atom_all
      |> Parser.new(preload: %{0 => :quux})
      |> fast_forward

      assert %Registers{x: %{0 => :quux}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on builtin atom" do
      state = @op_is_atom_all
      |> Parser.new(preload: %{0 => builtin(:atom)})
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_atom_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_atom_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:atom)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_tuple opcode" do
    @op_is_tup {:test, :is_tuple, {:f, 10}, [x: 0]}
    @op_is_tup_all [@op_is_tup, @op_set0]

    test "forward propagates the type on an any tuple" do
      state = @op_is_tup_all
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: :any}})
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: :any}}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on an a defined tuple" do
      state = @op_is_tup_all
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: [builtin(:any)]}})
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: [builtin(:any)]}}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_tup_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_tup_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: :any}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_tagged_tuple opcode" do
    @op_is_ttup {:test, :is_tagged_tuple, {:f, 10}, [{:x, 0}, 2, {:atom, :tag}]}
    @op_is_ttup_all [@op_is_ttup, @op_set0]

    test "forward propagates the type on an any tuple" do
      state = @op_is_ttup_all
      |> Parser.new(preload: %{0 => %Type.Tuple{elements: [:tag, builtin(:any)]}})
      |> fast_forward

      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_ttup_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_ttup_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Tuple{elements: [:tag, builtin(:any)]}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_list opcode" do
    @op_is_lst {:test, :is_list, {:f, 10}, [x: 0]}
    @op_is_lst_all [@op_is_lst, @op_set0]
    @any_list %Type.List{type: builtin(:any)}

    test "forward propagates the type on a general list" do
      state = @op_is_lst_all
      |> Parser.new(preload: %{0 => @any_list})
      |> fast_forward

      assert %Registers{x: %{0 => @any_list}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type on a list with any final" do
      state = @op_is_lst_all
      |> Parser.new(preload: %{0 => %Type.List{type: builtin(:any), final: builtin(:any)}})
      |> fast_forward

      assert %Registers{x: %{0 => %Type.List{type: builtin(:any), final: builtin(:any)}}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_lst_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_lst_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => %Type.List{type: builtin(:any), final: builtin(:any)}}}
        = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  @function_1 %Type.Function{params: [builtin(:any)], return: builtin(:any)}

  describe "is_function opcode" do
    @op_is_fun {:test, :is_function, {:f, 10}, [x: 0]}
    @op_is_fun_all [@op_is_fun, @op_set0]

    test "forward propagates the type on a function" do
      state = @op_is_fun_all
      |> Parser.new(preload: %{0 => @function_1})
      |> fast_forward

      assert %Registers{x: %{0 => @function_1}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_fun_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_fun_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Function{params: :any, return: builtin(:any)}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_function2 opcode with constant integer" do
    @op_is_f2_1 {:test, :is_function2, {:f, 10}, [x: 0, integer: 1]}
    @op_is_f2_1_all [@op_is_f2_1, @op_set0]

    test "forward propagates the type on correct-arity function" do
      state = @op_is_f2_1_all
      |> Parser.new(preload: %{0 => @function_1})
      |> fast_forward

      assert %Registers{x: %{0 => @function_1}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "forward propagates the type that matches the jump condition" do
      state = @op_is_f2_1_all
      |> Parser.new(preload: %{0 => builtin(:integer)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates when there's nothing in the test register" do
      state = @op_is_f2_1_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => %Type.Function{params: [builtin(:any)], return: builtin(:any)}}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "passes needs through a backpropagation"
  end

  describe "is_function2 opcode with param integer" do
    test "works"
  end

  test "make is_eq_exact operate on arbitrary types of things"

  describe "is_eq_exact opcode" do
    @op_is_eq_exact {:test, :is_eq_exact, {:f, 10}, [x: 0, x: 1]}
    @op_is_eq_exact_all [@op_is_eq_exact, @op_set0]

    test "forward propagates both types when types match" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:integer)})
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "forward propagates only the success type when it's a matching singleton type" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => :bar, 1 => :bar})
      |> fast_forward

      assert %Registers{x: %{0 => :bar, 1 => :bar}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
      assert length(state.histories) == 1
    end

    test "forward propagates only the failure type when it's a mismatching singleton type" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => 1, 1 => 2})
      |> fast_forward

      assert %Registers{x: %{0 => 1, 1 => 2}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
      assert length(state.histories) == 1
    end

    test "forward propagates the jump type if it's a mismatch" do
      state = @op_is_eq_exact_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:float)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:float)}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates any() when content is missing for either register" do
      state = @op_is_eq_exact_all
      |> Parser.new()
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
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:pid)})
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:pid)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:pid)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates any() when content is missing for either register" do
      state = @op_is_lt_all
      |> Parser.new()
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
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:integer)})
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 0)
      assert %Registers{x: %{0 => :foo}} = history_finish(state, 0)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:integer)}} = history_start(state, 1)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state, 1)
    end

    test "forward propagates only the fail type when it's a matching singleton type" do
      state = @op_is_ne_all
      |> Parser.new(preload: %{0 => 1, 1 => 1})
      |> fast_forward

      assert %Registers{x: %{0 => 1, 1 => 1}} = history_start(state)
      assert %Registers{x: %{0 => builtin(:float)}} = history_finish(state)
      assert length(state.histories) == 1
    end

    test "forward propagate fails when the matching singleton does not clear the fail jump"

    test "forward propagates the jump type if it's a mismatch" do
      state = @op_is_ne_all
      |> Parser.new(preload: %{0 => builtin(:integer), 1 => builtin(:atom)})
      |> fast_forward

      final = fast_forward(state)

      assert %Registers{x: %{0 => builtin(:integer), 1 => builtin(:atom)}} = history_start(state)
      assert %Registers{x: %{0 => :foo}} = history_finish(state)
    end

    test "what happens when the forward propagation is overbroad"

    test "what happens when the forward propagation is unmatched"

    test "forwards when the jump has multiple conditions"

    test "backpropagates any() when content is missing for either register" do
      state = @op_is_ne_all
      |> Parser.new()
      |> fast_forward

      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 0)
      assert %Registers{x: %{0 => builtin(:any), 1 => builtin(:any)}} = history_start(state, 1)
    end

    test "passes needs through a backpropagation"
  end
end
