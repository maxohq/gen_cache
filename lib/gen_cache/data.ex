defmodule GenCache.Data do
  defstruct busy: %{},
            cache: %{},
            valid_until: %{},
            ttl: %{},
            purge_loop: 1000,
            default_ttl: nil
end
