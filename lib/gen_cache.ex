defmodule GenCache do
  @moduledoc """
  Generic cache layer for anything.
  Allows concurrent requests without work duplication and blocking.

  Usage:
  ```
  {:ok, pid} = GenCache.start_link()

  # populate cache with default `ttl` value
  response = GenCache.request(pid, {Mod, :fun, [arg1, arg2]})

  # populate cache with custom `ttl` value
  response = GenCache.request(pid, {Mod, :fun, [arg1, arg2]}, ttl: :timer.seconds(15))
  ```

  Special notes:
  - we use a map to signify the state of the cache (usually this is an atom)
  - this map contains currently running cache misses
  - every change on this map triggers a state transition in gen_statem
  - the postponed requests get a chance to run again on each state transition
  """

  defmacro __using__(_) do
    quote do
      use GenCache.Macro
    end
  end

  alias GenCache.Data
  @behaviour :gen_statem

  @default_ttl :timer.seconds(30)

  def start_link(opts \\ []), do: :gen_statem.start_link(__MODULE__, [], opts)

  @impl true
  def callback_mode(), do: [:handle_event_function, :state_enter]

  @impl true
  def init(_) do
    # state / data / actions
    {:ok, %{}, %Data{}, []}
  end

  ### PUBLIC API ###

  def request(pid, request, opts \\ []), do: :gen_statem.call(pid, {:request, request, opts})
  def remove(pid, request), do: :gen_statem.call(pid, {:remove, request})
  def get_state(pid), do: :gen_statem.call(pid, :get_state)

  ### INTERNAL ###

  @impl :gen_statem
  def handle_event(:enter, _before_state, _after_state, _data), do: {:keep_state_and_data, []}

  # just return state / data
  def handle_event({:call, from}, :get_state, _state, data) do
    {:keep_state, data, [{:reply, from, data}]}
  end

  def handle_event({:call, from}, {:remove, request}, _state, data) do
    data =
      remove_from_cache(data, request)
      |> remove_valid_until(request)
      |> remove_ttl(request)

    {:keep_state, data, [{:reply, from, :ok}]}
  end

  #
  def handle_event({:call, from}, {:request, request, req_opts}, _, data) do
    ttl = Keyword.get(req_opts, :ttl, @default_ttl)
    data = update_ttl(data, request, ttl)
    {res, data} = get_from_cache(data, request)
    is_busy = is_busy_for_request(data, request)

    cond do
      # we have a result in cache, so we reply immediately
      res != nil ->
        actions = [{:reply, from, res}]
        {:keep_state, data, actions}

      # we are already busy with this request, so we postpone
      is_busy ->
        actions = [:postpone]
        {:keep_state_and_data, actions}

      # not in cache and no in-progress fetching, so we schedule a fetch
      true ->
        data = mark_busy_for_request(data, request, from)
        actions = [{:next_event, :internal, {:fetch_data, request, from}}]
        {:next_state, data.busy, data, actions}
    end
  end

  # Handle a successful fetch
  def handle_event(:cast, {:handle_ok_fetch, request, response, from}, _state, data) do
    data = mark_done_for_request(data, request)
    data = store_in_cache(data, request, response)
    data = update_valid_until(data, request)
    actions = [{:reply, from, response}]
    {:next_state, data.busy, data, actions}
  end

  # Handle a failed fetch
  def handle_event(:cast, {:handle_error_fetch, request, error, from}, _state, data) do
    data = mark_done_for_request(data, request)
    data = remove_ttl(data, request)
    actions = [{:reply, from, {:error, error}}]
    {:next_state, data.busy, data, actions}
  end

  def handle_event(:internal, {:fetch_data, {mod, fun, args} = request, from}, _s, _data) do
    pid = self()

    # run the fetch in a separate process, to unblock our main loop
    Task.start(fn ->
      response =
        try do
          {:ok, apply(mod, fun, args)}
        rescue
          error ->
            {:error, error}
        end

      case response do
        {:ok, result} ->
          GenServer.cast(pid, {:handle_ok_fetch, request, result, from})

        {:error, error} ->
          GenServer.cast(pid, {:handle_error_fetch, request, error, from})
      end
    end)

    {:keep_state_and_data, []}
  end

  defp is_busy_for_request(data, request) do
    Map.get(data.busy, request, false)
  end

  defp mark_busy_for_request(data, request, from) do
    %Data{data | busy: Map.put(data.busy, request, from)}
  end

  defp mark_done_for_request(data, request) do
    %Data{data | busy: Map.delete(data.busy, request)}
  end

  defp store_in_cache(data, request, res) do
    %Data{data | cache: Map.put(data.cache, request, res)}
  end

  defp remove_from_cache(data, request) do
    %Data{data | cache: Map.delete(data.cache, request)}
  end

  defp get_from_cache(data, request) do
    res = Map.get(data.cache, request, nil)

    if res do
      {res, update_valid_until(data, request)}
    else
      {nil, data}
    end
  end

  defp update_valid_until(data, request) do
    time = :erlang.monotonic_time()
    ttl = Map.get(data.ttl, request, @default_ttl)

    %Data{
      data
      | valid_until: Map.put(data.valid_until, request, time + ttl * 1_000_000)
    }
  end

  defp remove_valid_until(data, request) do
    %Data{data | valid_until: Map.delete(data.valid_until, request)}
  end

  defp update_ttl(data, request, ttl) do
    %Data{data | ttl: Map.put(data.ttl, request, ttl)}
  end

  defp remove_ttl(data, request) do
    %Data{data | ttl: Map.delete(data.ttl, request)}
  end

  def remove_expired_entries(data, now) do
    expired_keys = Enum.filter(data.valid_until, fn {_, v} -> v < now end)

    Enum.reduce(expired_keys, data, fn {k, _time}, acc ->
      acc
      |> remove_from_cache(k)
      |> remove_valid_until(k)
      |> remove_ttl(k)
    end)
  end
end
