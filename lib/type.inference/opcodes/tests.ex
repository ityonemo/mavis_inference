defmodule Type.Inference.Opcodes.Tests do

  import Type, only: :macros

  use Type.Inference.Macros

  alias Type.Inference.Module.ParallelParser

  opcode {:test, :is_integer, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, builtin(:integer)) | jump_needs]}
        Type.usable_as(fetch_type(state, from), builtin(:integer)) == :ok ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  @opdoc """
  takes the value in register `from` and checks if it's nil.  If it's nil, then proceed
  to the next opcode.  If it's not, then jump to block label `fail`
  """
  opcode {:test, :is_nil, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, nil) | jump_needs]}
        fetch_type(state, from) == nil ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_boolean, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, builtin(:boolean)) | jump_needs]}
        Type.usable_as(fetch_type(state, from), builtin(:boolean)) == :ok ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_atom, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, builtin(:atom)) | jump_needs]}
        Type.usable_as(fetch_type(state, from), builtin(:atom)) == :ok ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_tagged_tuple, {:f, fail}, [from, length, tag]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          tag_elems = List.duplicate(builtin(:any), length - 1)
          tag_tuple = %Type.Tuple{elements: [fetch_type(state, tag) | tag_elems]}
          {:backprop, [put_reg(state, from, tag_tuple) | jump_needs]}
        Type.usable_as(fetch_type(state, from), %Type.Tuple{elements: :any}) == :ok ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_tuple, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, %Type.Tuple{elements: :any}) | jump_needs]}
        Type.usable_as(fetch_type(state, from), %Type.Tuple{elements: :any}) == :ok ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_nonempty_list, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        ! is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, %Type.List{nonempty: true, type: builtin(:any)}) | jump_needs]}
        match?(%Type.List{nonempty: true}, fetch_type(state, from)) ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_list, {:f, fail}, [from]} do
    forward(state, _meta, ...) do
      # get the required values from the fail condition.
      jump_block = ParallelParser.obtain_label(fail)

      cond do
        not is_defined(state, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, from, %Type.List{final: builtin(:any)}) | jump_needs]}
        Type.usable_as(fetch_type(state, from), %Type.List{final: builtin(:any)}) == :ok ->
          {:ok, state}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_function, {:f, fail}, [fun]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_defined(state, fun) ->
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, fun, %Type.Function{params: :any, return: builtin(:any)}) | jump_needs]}
        match?(%Type.Function{}, fetch_type(state, fun)) ->
          {:ok, state}
        true ->
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_function2, {:f, fail}, [fun, integer: arity]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_defined(state, fun) ->
          params = List.duplicate(builtin(:any), arity)
          jump_needs = Enum.map(jump_block, &merge_reg(state, &1.needs))
          {:backprop, [put_reg(state, fun, %Type.Function{params: params, return: builtin(:any)}) | jump_needs]}
        match?(%Type.Function{params: params} when length(params) == arity, fetch_type(state, fun)) ->
          {:ok, state}
        true ->
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
      end
    end
  end

  # TODO: put this into mavis.
  defguard is_singleton(value) when is_atom(value) or is_integer(value)

  opcode {:test, :is_eq_exact, {:f, fail}, [left, right]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        ! is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        is_singleton(fetch_type(state, left)) and fetch_type(state, left) == fetch_type(state, right) ->
          {:ok, state}
        is_singleton(fetch_type(state, left)) and is_singleton(fetch_type(state, right)) ->
          {:ok, freeze: put_reg(state, left, jump_res.makes)}
        Type.intersection(fetch_type(state, left), fetch_type(state, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(state, left, jump_res.makes)}
        true ->
          {:ok, [state, freeze: put_reg(state, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_lt, {:f, fail}, [left, right]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        ! is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        true ->
          {:ok, [state, freeze: put_reg(state, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_ne, {:f, fail}, [left, right]} do
    forward(state, _meta, ...) do
      jump_block = ParallelParser.obtain_label(fail)
      [jump_res] = jump_block

      cond do
        ! is_defined(state, left) ->
          {:backprop, [put_reg(state, left, builtin(:any))]}
        ! is_defined(state, right) ->
          {:backprop, [put_reg(state, right, builtin(:any))]}
        is_singleton(fetch_type(state, left)) and fetch_type(state, left) == fetch_type(state, right) ->
          {:ok, freeze: put_reg(state, {:x, 0}, jump_res.makes)}
        is_singleton(fetch_type(state, left)) and is_singleton(fetch_type(state, right)) ->
          {:ok, state}
        Type.intersection(fetch_type(state, left), fetch_type(state, right)) == builtin(:none) ->
          {:ok, state}
        true ->
          {:ok, [state, freeze: put_reg(state, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end
end
