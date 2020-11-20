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
        Type.usable_as(get_reg(regs, from), builtin(:integer)) == :ok ->
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
        Type.usable_as(get_reg(regs, from), builtin(:float)) == :ok ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop :terminal
  end

  defp put_new_reg(regs = %{x: x_regs}, {:x, reg}, _type)
      when is_map_key(x_regs, reg), do: regs

  defp put_new_reg(regs, id, type), do: put_reg(regs, id, type)

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
          jump_needs = jump_block
          |> Enum.map(&merge_reg(regs, &1.needs))
          |> Enum.map(&put_new_reg(&1, from, builtin(:any)))

          {:backprop, [put_reg(regs, from, nil) | jump_needs]}
        get_reg(regs, from) == nil ->
          {:ok, regs}
        true ->
          [jump_res] = jump_block
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
      end
    end

    backprop(out_regs, in_regs, meta, ...) do
      raise "foo"
      #cond do
      #  get_reg(regs, from) == nil ->
      #    {:ok, regs}
      #  true ->
      #    jump_block = {meta.module, fail}
      #    |> BlockCache.depend_on()
      #    |> block_needs
#
      #    {:ok, merge_regs(regs, jump_block)}
      #end
    end
  end

  opcode {:test, :is_boolean, {:f, fail}, [from]} do
    forward(regs, meta, ...) do
      # get the required values from the fail condition.
      jump_block = BlockCache.depend_on({meta.module, fail})

      cond do
        not is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, builtin(:boolean)) | jump_needs]}
        Type.usable_as(get_reg(regs, from), builtin(:boolean)) == :ok ->
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
        Type.usable_as(get_reg(regs, from), builtin(:atom)) == :ok ->
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
          tag_tuple = %Type.Tuple{elements: [get_reg(regs, tag) | tag_elems]}
          {:backprop, [put_reg(regs, from, tag_tuple) | jump_needs]}
        Type.usable_as(get_reg(regs, from), %Type.Tuple{elements: {:min, 0}}) == :ok ->
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
        Type.usable_as(get_reg(regs, from), %Type.Tuple{elements: {:min, 0}}) == :ok ->
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
      |> IO.inspect(label: "174")

      cond do
        ! is_defined(regs, from) ->
          jump_needs = Enum.map(jump_block, &merge_reg(regs, &1.needs))
          {:backprop, [put_reg(regs, from, %Type.List{nonempty: true, type: builtin(:any)}) | jump_needs]}
        match?(%Type.List{nonempty: true}, get_reg(regs, from)) ->
          {:ok, regs}
        true ->
          {:ok, Enum.map(jump_block, fn block ->
            {:freeze, put_reg(regs, {:x, 0}, block.makes)}
          end)}
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
        Type.usable_as(get_reg(regs, from), %Type.List{final: builtin(:any)}) == :ok ->
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
        Type.usable_as(get_reg(regs, from), @any_map) == :ok ->
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
        match?(builtin(:pid), get_reg(regs, fun)) ->
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
        match?(builtin(:port), get_reg(regs, fun)) ->
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
        match?(builtin(:reference), get_reg(regs, fun)) ->
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
        match?(%Type.Function{}, get_reg(regs, fun)) ->
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
        match?(%Type.Bitstring{size: size, unit: unit} when rem(unit, 8) == 0 and rem(size, 8) == 0, get_reg(regs, fun)) ->
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
        match?(%Type.Function{params: params} when length(params) == arity, get_reg(regs, fun)) ->
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
        is_singleton(get_reg(regs, left)) and get_reg(regs, left) == get_reg(regs, right) ->
          {:ok, regs}
        is_singleton(get_reg(regs, left)) and is_singleton(get_reg(regs, right)) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        Type.intersection(get_reg(regs, left), get_reg(regs, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end

  # TODO: move this to a general tool.
  @spec block_needs(Block.t) :: %{optional(integer) => Type.t}
  defp block_needs(block) do
    Enum.reduce(block, %{}, fn blockdef, acc ->
      type_union_merge_into(blockdef.needs, acc)
    end)
  end

  defp type_union_merge_into(src, dst) do
    Enum.reduce(src, dst, fn
      {key, val}, acc when is_map_key(acc, key) ->
        %{dst | key => Type.union(dst[key], val)}
      {key, val}, acc -> Map.put(acc, key, val)
    end)
  end

  defp merge_regs(regs, x_regs) do
    %{regs | x: type_union_merge_into(regs.x, x_regs)}
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
        is_singleton(get_reg(regs, left)) and get_reg(regs, left) == get_reg(regs, right) ->
          {:ok, regs}
        is_singleton(get_reg(regs, left)) and is_singleton(get_reg(regs, right)) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        Type.intersection(get_reg(regs, left), get_reg(regs, right)) == builtin(:none) ->
          {:ok, freeze: put_reg(regs, left, jump_res.makes)}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop(out_regs, in_regs, meta, ...) do
      raise "foo"
#      jump_block = {meta.module, fail}
#      |> BlockCache.depend_on()
#      |> block_needs
#
#      {:ok, merge_regs(regs, jump_block)}
    end
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
        is_singleton(get_reg(regs, left)) and get_reg(regs, left) == get_reg(regs, right) ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
        is_singleton(get_reg(regs, left)) and is_singleton(get_reg(regs, right)) ->
          {:ok, regs}
        Type.intersection(get_reg(regs, left), get_reg(regs, right)) == builtin(:none) ->
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
        is_singleton(get_reg(regs, left)) and get_reg(regs, left) == get_reg(regs, right) ->
          {:ok, freeze: put_reg(regs, {:x, 0}, jump_res.makes)}
        is_singleton(get_reg(regs, left)) and is_singleton(get_reg(regs, right)) ->
          {:ok, regs}
        Type.intersection(get_reg(regs, left), get_reg(regs, right)) == builtin(:none) ->
          {:ok, regs}
        true ->
          {:ok, [regs, freeze: put_reg(regs, {:x, 0}, jump_res.makes)]}
      end
    end

    backprop :terminal
  end
end
