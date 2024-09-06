defmodule GenCache.Data do
  defstruct busy: %{}, cache: %{}, valid_until: %{}, expire_in: %{}
end
