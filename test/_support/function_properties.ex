defmodule TypeTest.FunctionProperties do

  def has_opcode?({m, f, a}, desired_opcode) do
    with {^m, binary, _filepath} <- :code.get_object_code(m),
         {:beam_file, ^m, _funs_list, _vsn, _meta, functions} <- :beam_disasm.file(binary) do
      code = Enum.find_value(functions,
        fn
          {:function, ^f, ^a, _, code} -> code
          _ -> false
        end)

      unless code do
        raise "function #{inspect m}.#{f}/#{a} not found."
      end

      Enum.any?(code, fn
        opcode when is_tuple(opcode) ->
          opcode
          |> Tuple.to_list
          |> Enum.zip(desired_opcode)
          |> Enum.all?(fn {a, b} -> a == b end)
        _ -> false
      end)
    else
      _ -> raise "function #{inspect m}.#{f}/#{a} not found."
    end
  end
end
