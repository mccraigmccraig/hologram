defmodule HologramFeatureTests.JSDebug do
  @moduledoc """
  Debug helpers for capturing JavaScript state from the browser during tests.

  Uses `globalThis` slots + `Wallaby.Chrome.execute_script/4` with
  `check_logs: false` to survive page crashes.

  ## Usage

      # Wrap any function:
      # In page action — arity must match the target function:
      Hologram.JS.eval(JSDebug.wrap_debug("Elixir_Hologram_Skuld_JSRef", "__resolve__/2", 2))
      Hologram.JS.eval(JSDebug.wrap_debug("Elixir_Skuld_Coroutine", "call/2", 2))

      # In test:
      keys =
        JSDebug.debug_keys("Elixir_Hologram_Skuld_JSRef", "__resolve__/2") ++
          JSDebug.debug_keys("Elixir_Skuld_Coroutine", "call/2")

      session = JSDebug.dump_keys(session, keys)

      # Scatter printf-debug calls in any Skuld/Hologram code:
      JSDebug.log(:warn, "entering slow path")

      # Activate capture in page action:
      Hologram.JS.eval(JSDebug.setup_log())

      # Read back in test:
      session = JSDebug.dump_keys(session, JSDebug.log_keys())

  ## Safety constraints

  Hologram-struct references cannot be stored on `globalThis` (crashes
  the tab), and `arguments` is unavailable in the eval context.
  Wrappers use positional args and store only primitives:

    * `_input__`  → `%{n: arity}` (arg count only)
    * `_output__` → `%{t: typeof result}` (type descriptor)
    * `_error__`  → error string (from `String(e)`)
  """

  # ---
  # Public API: reading debug values from the browser
  # ---

  @doc """
  Reads debug keys from the browser and prints each to stdout via `IO.puts`.
  Returns the session for pipeline use.

  Uses `Wallaby.Chrome.execute_script/4` with `check_logs: false` to
  survive page crashes / JS errors.
  """
  def dump_keys(session, keys) do
    Enum.each(keys, fn key ->
      case Wallaby.Chrome.execute_script(session, "return globalThis.#{key}", [],
             check_logs: false
           ) do
        {:ok, val} -> IO.puts("#{key}: #{inspect(val)}")
        other -> IO.puts("#{key}: (raw) #{inspect(other)}")
      end
    end)

    session
  end

  # ---
  # Public API: printf-debug logging
  # ---

  @doc """
  No-op log sink. Delegated to by `log/2`.

  Wrap via `setup_log/0` to capture calls on `globalThis`.
  """
  def do_log(_level, _message), do: :ok

  @doc """
  printf-debug logger. Calls `do_log/2` (no-op by default).
  Scatter anywhere in Skuld or Hologram code.

  After calling `Hologram.JS.eval(JSDebug.setup_log())` in a page action,
  reads back via `JSDebug.log_keys()` + `JSDebug.dump_keys/2`.
  """
  def log(level, message), do: do_log(level, message)

  @doc """
  Returns the JS eval string to activate log capture.
  """
  def setup_log, do: wrap_debug("Elixir_HologramFeatureTests_JSDebug", "do_log/2", 2)

  @doc """
  Returns the debug key names for `do_log/2`.
  """
  def log_keys, do: debug_keys("Elixir_HologramFeatureTests_JSDebug", "do_log/2")

  # ---
  # Public API: generating JS wrapper strings
  # ---

  @doc """
  Returns a JS IIFE string that wraps a function with debug logging on
  `globalThis`. Automatically detects whether the result is a Promise
  and chains `.then`/`.catch` accordingly.

  `arity` must match the target function's parameter count.

  ## Paths covered

    * Logs input metadata (arg count)
    * Calls target with positional args in try/catch
    * Sync throw → log error, re-throw
    * Sync return → log output type, return
    * Promise resolve → log output type, delegate
    * Promise reject → log error, re-throw
  """
  def wrap_debug(module_js_var, fn_key, arity) when is_integer(arity) and arity >= 0 do
    prefix = dbg_prefix(module_js_var, fn_key)
    args = args_list(arity)
    dumps = dump_lines(arity)
    dump_obj = dump_obj(arity)

    """
    (function(){var o=#{module_js_var}['#{fn_key}'];
    #{module_js_var}['#{fn_key}']=function(#{args}){
    #{dumps}
      globalThis.#{prefix}_input__=#{dump_obj};
      try{
        var r=o(#{args});
        if(r!=null&&typeof r.then==='function'){
          return r.then(function(v){
            globalThis.#{prefix}_output__={t:typeof v};
            return v;
          }).catch(function(e){
            globalThis.#{prefix}_error__=String(e);
            throw e;
          });
        }else{
          globalThis.#{prefix}_output__={t:typeof r};
          return r;
        }
      }catch(e){
        globalThis.#{prefix}_error__=String(e);
        throw e;
      }
    };})()
    """
  end

  # ---
  # Public API: debug key name helpers
  # ---

  @doc """
  Returns the standard debug key names written by `wrap_debug/3`.
  """
  def debug_keys(module_js_var, fn_key) do
    prefix = dbg_prefix(module_js_var, fn_key)
    ["#{prefix}_input__", "#{prefix}_output__", "#{prefix}_error__"]
  end

  # ---
  # Internal
  # ---

  defp args_list(0), do: ""
  defp args_list(1), do: "a0"
  defp args_list(2), do: "a0,a1"
  defp args_list(3), do: "a0,a1,a2"
  defp args_list(4), do: "a0,a1,a2,a3"

  defp dump_lines(0), do: ""

  defp dump_lines(1) do
    "var d0;try{d0=JSON.stringify(a0);}catch(e){d0=String(a0);};"
  end

  defp dump_lines(2) do
    "var d0;try{d0=JSON.stringify(a0);}catch(e){d0=String(a0);};\nvar d1;try{d1=JSON.stringify(a1);}catch(e){d1=String(a1);};"
  end

  defp dump_lines(3) do
    "var d0;try{d0=JSON.stringify(a0);}catch(e){d0=String(a0);};\nvar d1;try{d1=JSON.stringify(a1);}catch(e){d1=String(a1);};\nvar d2;try{d2=JSON.stringify(a2);}catch(e){d2=String(a2);};"
  end

  defp dump_lines(4) do
    "var d0;try{d0=JSON.stringify(a0);}catch(e){d0=String(a0);};\nvar d1;try{d1=JSON.stringify(a1);}catch(e){d1=String(a1);};\nvar d2;try{d2=JSON.stringify(a2);}catch(e){d2=String(a2);};\nvar d3;try{d3=JSON.stringify(a3);}catch(e){d3=String(a3);};"
  end

  defp dump_obj(0), do: "{n:0}"
  defp dump_obj(1), do: "{n:1,a0:d0}"
  defp dump_obj(2), do: "{n:2,a0:d0,a1:d1}"
  defp dump_obj(3), do: "{n:3,a0:d0,a1:d1,a2:d2}"
  defp dump_obj(4), do: "{n:4,a0:d0,a1:d1,a2:d2,a3:d3}"

  defp dbg_prefix(module_js_var, fn_key) do
    mod =
      module_js_var
      |> String.replace_leading("Elixir_", "")
      |> String.replace(".", "_")

    fn_norm =
      fn_key
      |> String.replace("/", "_")
      |> String.replace("__", "_")

    "__dbg_#{mod}_#{fn_norm}"
  end
end
