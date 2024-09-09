defmodule GenCache.Data do
  defstruct ttl: %{},
            busy: %{},
            cache: %{},
            valid_until: %{},
            purge_loop: 1000,
            default_ttl: 30000
end
