defmodule GenCache.Macro do
  defmacro __using__(_opts) do
    quote do
      @mymodule String.replace("#{__MODULE__}", "Elixir.", "")

      @moduledoc """
      Generic cache layer for anything.
      Allows concurrent requests without work duplication and blocking.

      Usage:
      ```
      {:ok, pid} = #{@mymodule}.start_link()

      # populate cache with default `expire_in` value
      response = #{@mymodule}.request(pid, {Mod, :fun, [arg1, arg2]})

      # populate cache with custom `expire_in` value
      response = #{@mymodule}.request(pid, {Mod, :fun, [arg1, arg2]}, expire_in: :timer.seconds(15))
      ```

      Special notes:
      - we use a map to signify the state of the cache (usually this is an atom)
      - this map contains currently running cache misses
      - every change on this map triggers a state transition in gen_statem
      - the postponed requests get a chance to run again on each state transition
      """

      alias GenCache.Data
      @behaviour :gen_statem

      # for some reason dialyzer doesn't like our `start_link` function
      @dialyzer {:nowarn_function, [{:start_link, 1}]}

      @default_expire_in :timer.seconds(30)

      @impl true
      def callback_mode(), do: [:handle_event_function, :state_enter]

      def start_link(opts \\ []) do
        with {:check, nil} <- {:check, Process.whereis(__MODULE__)},
             {:ok, pid} <- :gen_statem.start_link(__MODULE__, [], opts) do
          Process.register(pid, __MODULE__)
          {:ok, pid}
        else
          {:check, pid} -> {:error, {:already_started, pid}}
        end
      end

      @impl true
      def init(_) do
        # state / data / actions
        {:ok, %{}, %Data{}, []}
      end

      ### PUBLIC API ###

      def request(request, opts \\ []),
        do: :gen_statem.call(__MODULE__, {:request, request, opts})

      def remove(request), do: :gen_statem.call(__MODULE__, {:remove, request})
      def get_state(), do: :gen_statem.call(__MODULE__, :get_state)

      ### INTERNAL ###

      @impl :gen_statem
      def handle_event(a1, a2, a3, a4) do
        GenCache.handle_event(a1, a2, a3, a4)
      end
    end
  end
end
