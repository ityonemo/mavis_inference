defmodule TypeTest.ModuleExamples do
  defmodule WithDef do
    def function(x), do: x
  end

  defmodule WithDefp do
    # this needs to be here to prevent erlang from aggressively
    # cutting the function out through dead code elimination
    def function(x), do: functionp(x)

    defp functionp(x), do: x
  end

  defmodule WithLambda do
    def lambda, do: &functionp/1
    defp functionp(x), do: x
  end

end
