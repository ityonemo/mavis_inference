defmodule Type.UnknownOpcodeError do
  defexception [:opcode, :code_block, :mfa]

  @impl true
  def message(msg = %{mfa: {m, f, a}}) do
    """
    from #{inspect m}.#{f}./#{a}:
    """ <> message(Map.delete(msg, :mfa))
  end
  def message(%{opcode: opcode, code_block: code_block})
      when not is_nil(code_block) do
    """
      unknown opcode #{inspect opcode}, in block:
    #{Code.format_string!(inspect code_block)}
    """
  end
  def message(%{opcode: opcode}) do
    "unknown opcode #{inspect opcode}, block not captured."
  end
end
