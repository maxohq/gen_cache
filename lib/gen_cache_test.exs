defmodule GenCacheTest do
  use ExUnit.Case
  doctest GenCache

  defmodule ReqBackend do
    def fetch(request) do
      Process.sleep(20)
      "RESULT: #{inspect(request)}"
    end
  end

  def req_tuple(value) do
    {ReqBackend, :fetch, [value]}
  end

  describe "full run" do
    test "multiple tasks with same request get the same result" do
      {:ok, pid} = GenCache.start_link([])

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            GenCache.request(pid, req_tuple(1))
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 5
      [first_result | rest] = results
      assert Enum.all?(rest, &(&1 == first_result))
    end

    test "multiple tasks with different requests work fine" do
      {:ok, pid} = GenCache.start_link([])

      # we populate the cache
      pop_tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            GenCache.request(pid, req_tuple(:rand.uniform(3)))
          end)
        end

      fetch_tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            GenCache.request(pid, req_tuple(1))
            GenCache.request(pid, req_tuple(2))
            GenCache.request(pid, req_tuple(3))
          end)
        end

      Task.await_many(pop_tasks ++ fetch_tasks)

      assert GenCache.request(pid, req_tuple(1)) == "RESULT: 1"
      state = clean_state(pid)

      assert state ==
               %GenCache.Data{
                 busy: %{},
                 cache: %{
                   {GenCacheTest.ReqBackend, :fetch, [1]} => "RESULT: 1",
                   {GenCacheTest.ReqBackend, :fetch, [2]} => "RESULT: 2",
                   {GenCacheTest.ReqBackend, :fetch, [3]} => "RESULT: 3"
                 },
                 ttl: %{
                   {GenCacheTest.ReqBackend, :fetch, [1]} => 30000,
                   {GenCacheTest.ReqBackend, :fetch, [2]} => 30000,
                   {GenCacheTest.ReqBackend, :fetch, [3]} => 30000
                 },
                 default_ttl: 30000,
                 purge_loop: 5000
               }
    end
  end

  describe "remove_cache" do
    test "works" do
      {:ok, pid} = GenCache.start_link([])
      GenCache.request(pid, req_tuple(1))
      GenCache.request(pid, req_tuple(2))
      GenCache.remove(pid, req_tuple(1))

      assert clean_state(pid) == %GenCache.Data{
               busy: %{},
               ttl: %{
                 {GenCacheTest.ReqBackend, :fetch, [2]} => 30000
               },
               cache: %{{GenCacheTest.ReqBackend, :fetch, [2]} => "RESULT: 2"},
               default_ttl: 30000,
               purge_loop: 5000
             }
    end
  end

  describe "remove_expired" do
    test "works" do
      {:ok, pid} = GenCache.start_link([])

      GenCache.request(pid, req_tuple(1), ttl: :timer.seconds(5))
      GenCache.request(pid, req_tuple(2), ttl: :timer.seconds(10))
      GenCache.request(pid, req_tuple(3), ttl: :timer.seconds(15))
      # default ttl - 30 seconds
      GenCache.request(pid, req_tuple(4))

      now = :erlang.monotonic_time()

      data = GenCache.get_state(pid)
      time_factor = 1_000_000

      data1 = GenCache.remove_expired_entries(data, now + :timer.seconds(5) * time_factor)

      assert data1.cache == %{
               {GenCacheTest.ReqBackend, :fetch, [2]} => "RESULT: 2",
               {GenCacheTest.ReqBackend, :fetch, [3]} => "RESULT: 3",
               {GenCacheTest.ReqBackend, :fetch, [4]} => "RESULT: 4"
             }

      data2 = GenCache.remove_expired_entries(data, now + :timer.seconds(10) * time_factor)

      assert data2.cache == %{
               {GenCacheTest.ReqBackend, :fetch, [3]} => "RESULT: 3",
               {GenCacheTest.ReqBackend, :fetch, [4]} => "RESULT: 4"
             }

      data3 = GenCache.remove_expired_entries(data, now + :timer.seconds(15) * time_factor)

      assert data3.cache == %{
               {GenCacheTest.ReqBackend, :fetch, [4]} => "RESULT: 4"
             }

      data4 = GenCache.remove_expired_entries(data, now + :timer.seconds(30) * time_factor)

      assert data4.cache == %{}
    end
  end

  describe "raising response" do
    test "is not cached" do
      defmodule RaisingBackend do
        def fetch(_) do
          raise "THERE WAS AN ERROR"
        end
      end

      {:ok, pid} = GenCache.start_link([])

      assert {:error, %RuntimeError{message: "THERE WAS AN ERROR"}} ==
               GenCache.request(pid, {RaisingBackend, :fetch, [1]})

      assert "RESULT: 1" = GenCache.request(pid, {ReqBackend, :fetch, [1]})

      assert GenCache.get_state(pid).cache == %{
               {GenCacheTest.ReqBackend, :fetch, [1]} => "RESULT: 1"
             }
    end
  end

  def clean_state(pid) do
    GenCache.get_state(pid) |> Map.put(:valid_until, %{})
  end
end
