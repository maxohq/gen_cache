## v0.2.0 (2025-01-23)

### Added verbose option for per-instance logging control

- Added `verbose` option (default: `false`) to control debug logging per cache instance
- When `verbose: false` (default), purge cycle and expiration logs are suppressed
- When `verbose: true`, debug logs for "RUNNING PURGE" and expired keys are emitted
- This allows running caches silently in production while enabling verbose logging for debugging

```elixir
# Silent (default)
MyCache.start_link()

# Verbose logging enabled
MyCache.start_link(verbose: true)
```

## v0.1.2 (2024-12-30)

### Implements Reset function

- `GenCache.reset(pid)`
- or macro-based module: `SomeCache.reset()`


## v0.1.1 (2024-09-09)


### Quality of life improvements

- allow configuring default ttl when starting the server
- implements a periodic configurable purge of expired entries
- handles exectiptions when the MFA call raises
- some readme updates

## v0.1.0 (2024-09-06)

### First release

- already quite usable, there might still be some missing  features
