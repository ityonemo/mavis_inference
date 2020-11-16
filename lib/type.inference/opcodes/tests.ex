defmodule Type.Inference.Opcodes.Tests do
  use Type.Inference.Opcodes

  alias Type.Inference.Application.BlockCache

  opcode {:test, :is_integer, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from the fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, builtin(:integer)) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), builtin(:integer)) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_float, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from the fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, builtin(:float)) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), builtin(:float)) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  @opdoc """
  takes the value in register `from` and checks if it's nil.  If it's nil, then proceed
  to the next opcode.  If it's not, then jump to block label `fail`
  """
  opcode {:test, :is_nil, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from the fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, nil) | jump_needs]}
        fetch_type(regs, from) == nil ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_boolean, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from the fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, builtin(:boolean)) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), builtin(:boolean)) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_atom, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from te fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, builtin(:atom)) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), builtin(:atom)) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_tagged_tuple, {:f, fail}, [from, length, tag]} do
    forward(regs, meta, ...) do
      # get the required values from te fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})
      
      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          tag_elems = List.duplicate(builtin(:any), length - 1)
          tag_tuple = %Type.Tuple{elements: [fetch_type(regs, tag) | tag_elems]}
          {:backprop, [put_reg(regs, from, tag_tuple) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), %Type.Tuple{elements: {:min, 0}}) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_tuple, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from te fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, %Type.Tuple{elements: {:min, 0}}) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), %Type.Tuple{elements: {:min, 0}}) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_nonempty_list, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        ! is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, %Type.List{nonempty: true, type: builtin(:any)}) | jump_needs]}
        match?(%Type.List{nonempty: true}, fetch_type(regs, from)) ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_list, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from te fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, %Type.List{final: builtin(:any)}) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), %Type.List{final: builtin(:any)}) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  @any_map %Type.Map{optional: %{builtin(:any) => builtin(:any)}}

  opcode {:test, :is_map, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from te fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, @any_map) | jump_needs]}
        Type.usable_as(fetch_type(regs, from), @any_map) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_pid, {:f, fail}, [fun]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, fun) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, fun, builtin(:pid)) | jump_needs]}
        match?(builtin(:pid), fetch_type(regs, fun)) ->
          {:ok, regs}
        true ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_port, {:f, fail}, [fun]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, fun) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, fun, builtin(:port)) | jump_needs]}
        match?(builtin(:port), fetch_type(regs, fun)) ->
          {:ok, regs}
        true ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_reference, {:f, fail}, [fun]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, fun) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, fun, builtin(:reference)) | jump_needs]}
        match?(builtin(:reference), fetch_type(regs, fun)) ->
          {:ok, regs}
        true ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_function, {:f, fail}, [fun]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, fun) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, fun, %Type.Function{params: :any, return: builtin(:any)}) | jump_needs]}
        match?(%Type.Function{}, fetch_type(regs, fun)) ->
          {:ok, regs}
        true ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_binary, {:f, fail}, [fun]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, fun) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, fun, %Type.Bitstring{unit: 8}) | jump_needs]}
        match?(%Type.Bitstring{size: size, unit: unit} when rem(unit, 8) == 0 and rem(size, 8) == 0, fetch_type(regs, fun)) ->
          {:ok, regs}
        true ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_function2, {:f, fail}, [fun, integer: arity]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, fun) ->
          params = List.duplicate(builtin(:any), arity)
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, fun, %Type.Function{params: params, return: builtin(:any)}) | jump_needs]}
        match?(%Type.Function{params: params} when length(params) == arity, fetch_type(regs, fun)) ->
          {:ok, regs}
        true ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end
  end

  opcode {:test, :is_eq, {:f, fail}, [left, right]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, left) ->
          {:backprop, [put_reg(regs, left, builtin(:any))]}
        ! is_defined(regs, right) ->
          {:backprop, [put_reg(regs, right, builtin(:any))]}
        is_singleton(fetch_type(regs, left)) and fetch_type(regs, left) == fetch_type(regs, right) ->
          {:ok, regs}
        is_singleton(fetch_type(regs, left)) and is_singleton(fetch_type(regs, right)) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        Type.intersection(fetch_type(regs, left), fetch_type(regs, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_eq_exact, {:f, fail}, [left, right]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, left) ->
          {:backprop, [put_reg(regs, left, builtin(:any))]}
        ! is_defined(regs, right) ->
          {:backprop, [put_reg(regs, right, builtin(:any))]}
        is_singleton(fetch_type(regs, left)) and fetch_type(regs, left) == fetch_type(regs, right) ->
          {:ok, regs}
        is_singleton(fetch_type(regs, left)) and is_singleton(fetch_type(regs, right)) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        Type.intersection(fetch_type(regs, left), fetch_type(regs, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_lt, {:f, fail}, [left, right]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, left) ->
          {:backprop, [put_reg(regs, left, builtin(:any))]}
        ! is_defined(regs, right) ->
          {:backprop, [put_reg(regs, right, builtin(:any))]}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  # TODO: fuse this with is_lt once we get with statements in the opcode header.
  opcode {:test, :is_ge, {:f, fail}, [left, right]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, left) ->
          {:backprop, [put_reg(regs, left, builtin(:any))]}
        ! is_defined(regs, right) ->
          {:backprop, [put_reg(regs, right, builtin(:any))]}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  # TODO: fuse this with is_ne_exact, once we get with statements in the opcode header
  opcode {:test, :is_ne, {:f, fail}, [left, right]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, left) ->
          {:backprop, [put_reg(regs, left, builtin(:any))]}
        ! is_defined(regs, right) ->
          {:backprop, [put_reg(regs, right, builtin(:any))]}
        is_singleton(fetch_type(regs, left)) and fetch_type(regs, left) == fetch_type(regs, right) ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
        is_singleton(fetch_type(regs, left)) and is_singleton(fetch_type(regs, right)) ->
          {:ok, regs}
        Type.intersection(fetch_type(regs, left), fetch_type(regs, right)) == builtin(:none) ->
          {:ok, regs}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  opcode {:test, :is_ne_exact, {:f, fail}, [left, right]} do
    forward(regs, meta, ...) do
      jump_block = BlockCache.depend_on({meta.module, fail})
      [jump_res] = jump_block

      cond do
        ! is_defined(regs, left) ->
          {:backprop, [put_reg(regs, left, builtin(:any))]}
        ! is_defined(regs, right) ->
          {:backprop, [put_reg(regs, right, builtin(:any))]}
        is_singleton(fetch_type(regs, left)) and fetch_type(regs, left) == fetch_type(regs, right) ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
        is_singleton(fetch_type(regs, left)) and is_singleton(fetch_type(regs, right)) ->
          {:ok, regs}
        Type.intersection(fetch_type(regs, left), fetch_type(regs, right)) == builtin(:none) ->
          {:ok, regs}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end
end
