defmodule Hologram.Skuld.Effects.JS do
  @moduledoc """
  Effect for calling JavaScript functions from Skuld fibers.

  Two operations with clear semantics:

    * `call/2` — returns the result directly. Sync JS calls return the
      value; async JS calls produce a `ForeignSuspend` that blocks the
      current fiber until the Promise resolves.
    * `async/2` — always wraps in `FiberPool.fiber`, returning a Handle
      for use with `await!`/`await_all!`. Use for concurrent launches.

  ## Usage

      comp do
        # Blocking async call (suspends current fiber):
        data <- JS.call(:fetch, ["/api/data"])

        # Concurrent async calls:
        h1 <- JS.async(:fetch, ["/api/a"])
        h2 <- JS.async(:fetch, ["/api/b"])
        [a, b] <- FiberPool.await_all!([h1, h2])
      end
      |> JS.with_handler()
      |> FiberPool.with_handler()
      |> ForeignResolver.Runner.run()
  """

  alias Skuld.Comp
  alias Skuld.Comp.ForeignSuspend
  alias Skuld.Effects.FiberPool
  alias Skuld.Effects.FreshInt
  alias Hologram.Skuld.JSRef

  @sig __MODULE__

  defmodule Call do
    @moduledoc false
    defstruct [:function, :args]
  end

  defmodule Async do
    @moduledoc false
    defstruct [:function, :args]
  end

  @doc """
  Call a JS function and return the result directly.

  For synchronous JS calls, the value is returned inline.
  For async JS calls (Promise), produces a `ForeignSuspend` that
  suspends the current fiber until resolution.

  The `function` can be an atom (looked up on `globalThis`)
  or a `%Hologram.JS.NativeValue{}` wrapping a JS function reference.
  """
  @spec call(atom() | term(), list()) :: Comp.Types.computation()
  def call(function, args \\ []) do
    Comp.effect(@sig, %Call{function: function, args: args})
  end

  @doc """
  Call a JS function as a concurrent fiber, returning a Handle.

  Always wraps in `FiberPool.fiber` — whether sync or async.
  Use with `FiberPool.await!/1` or `FiberPool.await_all!/1`.

      h <- JS.async(:fetch, ["/api/data"])
      result <- FiberPool.await!(h)
  """
  @spec async(atom() | term(), list()) :: Comp.Types.computation()
  def async(function, args \\ []) do
    Comp.effect(@sig, %Async{function: function, args: args})
  end

  @doc """
  Install the JS effect handler for a computation.
  """
  @spec with_handler(Comp.Types.computation()) :: Comp.Types.computation()
  def with_handler(comp) do
    Comp.with_handler(comp, @sig, &handle/3)
  end

  # call — never wraps in a fiber
  @doc false
  def handle(%Call{function: function, args: args}, env, k) do
    case Hologram.Skuld.Effects.JS.__native_call__(function, args) do
      {:sync, value} ->
        k.(value, env)

      {:async, ref} ->
        {id, id_env} = Comp.call(FreshInt.fresh_integer(), env, &Comp.identity_k/2)

        resume = fn value, resume_env ->
          k.(value, resume_env)
        end

        suspend = %ForeignSuspend{
          id: id,
          resume: resume,
          payload: %JSRef{ref: ref}
        }

        {suspend, id_env}
    end
  end

  # async — always wraps in a fiber
  @doc false
  def handle(%Async{function: function, args: args}, env, k) do
    case Hologram.Skuld.Effects.JS.__native_call__(function, args) do
      {:sync, value} ->
        fiber_comp = fn suspend_env, _suspend_k ->
          {value, suspend_env}
        end

        Comp.call(FiberPool.fiber(fiber_comp), env, k)

      {:async, ref} ->
        {id, id_env} = Comp.call(FreshInt.fresh_integer(), env, &Comp.identity_k/2)

        fiber_comp = fn suspend_env, _suspend_k ->
          suspend = %ForeignSuspend{
            id: id,
            resume: &Comp.identity_k/2,
            payload: %JSRef{ref: ref}
          }

          {suspend, suspend_env}
        end

        Comp.call(FiberPool.fiber(fiber_comp), id_env, k)
    end
  end

  @doc false
  @spec __native_call__(term(), list()) :: term()
  def __native_call__(_function, _args) do
    :erlang.nif_error(:not_available_on_server)
  end
end
