defmodule GenCache.MacroTest do
  use ExUnit.Case
  doctest GenCache.Macro

  defmodule TestCache do
    use GenCache
  end

  test "basics work" do
    TestCache.start_link()
    # we send ourselves a message as side-effect when fetching results
    # it should only be received once
    TestCache.request({Process, :send, [self(), :start, []]})
    TestCache.request({Process, :send, [self(), :start, []]})
    assert_received :start
    refute_received :start
  end

  test "duplicate `starts_link` calls are properly handled" do
    {:ok, pid} = TestCache.start_link()
    assert {:error, {:already_started, pid}} == TestCache.start_link()
  end

  test "reset works" do
    TestCache.start_link()
    TestCache.request({Process, :send, [self(), :start, []]})
    TestCache.request({Process, :send, [self(), :start, []]})
    assert_received :start
    refute_received :start

    ## RESET clears the cache, so the next request MUST be executed
    TestCache.reset()
    TestCache.request({Process, :send, [self(), :start, []]})
    assert_received :start
  end
end
