defmodule GenCache.Data do
  defstruct busy: %{}, cache: %{}, valid_until: %{}, ttl: %{}
end
