# GenCache

Generic cache for Elixir. It uses MFA tuples as keys, so you can cache any function call with low development effort.

By relying on `gen_statem`, it is able to prevent duplicate work on concurrent requests on the same key, while keeping the API simple.

The generation of the cache value is done in a separate process, so the main GenServer loop is never blocked. Also it is possible to generate multiple different expensive values in parallel, with all the callers waiting for the result. This happens transparently to the caller.

All thanks to the awesome [gen_statem](https://www.erlang.org/doc/apps/stdlib/gen_statem.html) module.


## Usage


```elixir
defmodule MyCache do
  use GenCache
end

# start the cache, that executes state entries purge every 1 second with a default ttl of 15 seconds
MyCache.start_link(purge_loop: :timer.seconds(1), default_ttl: :timer.seconds(15))

# this will execute the MFA tuple and store the result in the cache
# you should see "Hello World" printed to the console
res = MyCache.request({IO, :puts, ["Hello World"]})

# this will not execute the MFA tuple and just return the cached result
res = MyCache.request({IO, :puts, ["Hello World"]})


# add custom ttl for the given key
res = MyCache.request({IO, :puts, ["Quick one"]}, ttl: :timer.seconds(5))

## log debug messages
GenCache.Config.log_debug()

## log only info messages
GenCache.Config.log_info()
```

## TODO
- [ ] configurable default timeout
- [ ] periodic cleanup of expired entries
- [x] protect against raising exceptions in the MFA tuple

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gen_cache` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gen_cache, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gen_cache>.

