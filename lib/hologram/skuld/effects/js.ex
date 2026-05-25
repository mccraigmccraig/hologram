defmodule Hologram.Skuld.Effects.JS do
  @moduledoc """
  Effect for making asynchronous JavaScript calls from Skuld fibers.

  Raises a `ForeignSuspend` with a `JSRef` payload so the FiberPool
  scheduler bundles it with other foreign suspensions. The `ForeignResolver`
  protocol impl for `JSRef` resolves the Promise and resumes the fiber.

  ## Usage

      comp do
        result <- JS.call(:fetch, ["/api/data"])
        FiberPool.await!(h)
      end
      |> JS.with_handler()
      |> FiberPool.with_handler()
      |> ForeignResolver.Runner.run()

  ## Handler Installation

  The JS handler must be installed *inside* the FiberPool handler so
  fibers have access to `FreshInt` for suspend IDs:

      comp
      |> JS.with_handler()
      |> FiberPool.with_handler()
  """

  alias Skuld.Comp
  alias Skuld.Comp.ForeignSuspend
  alias Skuld.Effects.FreshInt
  alias Hologram.Skuld.JSRef

  @sig __MODULE__

  #############################################################################
  ## Operation struct
  #############################################################################

  defmodule Call do
    @moduledoc false
    defstruct [:function, :args]
  end

  #############################################################################
  ## Public API
  #############################################################################

  @doc """
  Call a JavaScript function asynchronously, producing a `ForeignSuspend`.

  The `function` can be:
  - An atom (looked up on `globalThis`), e.g. `:fetch`
  - A `%Hologram.JS.NativeValue{}` wrapping a JS function reference

  Returns a `ForeignSuspend` with a `JSRef` payload — the fiber suspends
  until the Promise resolves.
  """
  @spec call(atom() | term(), list()) :: Comp.Types.computation()
  def call(function, args \\ []) do
    Comp.effect(@sig, %Call{function: function, args: args})
  end

  #############################################################################
  ## Handler Installation
  #############################################################################

  @doc """
  Install the JS effect handler for a computation.

  Must be installed inside a `FiberPool.with_handler/1` scope so fibers
  have access to `FreshInt`.
  """
  @spec with_handler(Comp.Types.computation()) :: Comp.Types.computation()
  def with_handler(comp) do
    Comp.with_handler(comp, @sig, &handle/3)
  end

  #############################################################################
  ## Handler Implementation
  #############################################################################

  @doc false
  def handle(%Call{function: function, args: args}, env, k) do
    {id, id_env} = Comp.call(FreshInt.fresh_integer(), env, &Comp.identity_k/2)

    ref = Hologram.Skuld.Effects.JS.__native_call__(function, args)

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

  #############################################################################
  ## Native bridge — overridden by JS implementation
  #############################################################################

  @doc false
  @spec __native_call__(term(), list()) :: term()
  def __native_call__(_function, _args) do
    :erlang.nif_error(:not_available_on_server)
  end
end
