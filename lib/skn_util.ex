defmodule Skn.Util do
  @moduledoc """
      provide function to work with stdint
  """
  import Bitwise

  def l_dword(x) do
    x &&& 0xFFFFFFFF
  end

  def h_dword(x) do
    int32(uint64(x) >>> 32)
  end

  def get_bit(x, bit) do
    mask = (2 <<< (bit + 1)) - 1
    ((x &&& mask) >>> bit) &&& 1
  end

  def int8(x) do
    x = x &&& 0xFF
    if x > 0x7F do
      x - 0x100
    else
      x
    end
  end

  def uint8(x) do
    x = x &&& 0xFF
    if x < 0 do
      0x100 + x
    else
      x
    end
  end

  def int16(x) do
    x = x &&& 0xFFFF
    if x > 0x7FFF do
      x - 0x10000
    else
      x
    end
  end

  def uint16(x) do
    x = x &&& 0xFFFF
    if x < 0 do
      0x10000 + x
    else
      x
    end
  end

  def int32(x) do
    x = x &&& 0xFFFFFFFF
    if x > 0x7FFFFFFF do
      x - 0x100000000
    else
      x
    end
  end

  def uint32(x) do
    x = x &&& 0xFFFFFFFF
    if x < 0 do
      0x100000000 + x
    else
      x
    end
  end

  def int64(x) do
    x = x &&& 0xFFFFFFFFFFFFFFFF
    if x > 0x7FFFFFFFFFFFFFFF do
      x - 0x10000000000000000
    else
      x
    end
  end

  def uint64(x) do
    x = x &&& 0xFFFFFFFFFFFFFFFF
    if x < 0 do
      0x10000000000000000 + x
    else
      x
    end
  end

  def swap32(x) do
    ((x <<< 24) &&& 0xff000000) ||| ((x <<< 8) &&& 0x00ff0000)
    ||| ((x >>> 8) &&& 0x0000ff00) ||| ((x >>> 24) &&& 0x000000ff)
  end

  def check_reset_timer(name, msg, timeout) do
    ref = Process.get name
    if is_reference(ref) do
      false
    else
      ref = :erlang.send_after(timeout, self(), msg)
      Process.put name, ref
      true
    end
  end

  def cancel_timer(name, msg) do
    ref = Process.delete name
    if is_reference(ref) do
      :erlang.cancel_timer(ref)
      receive do
        ^msg -> :ok
      after
        0 -> :ok
      end
    end
  end

  def has_timer(name) do
    ref = Process.get name
    if is_reference(ref) do
      r = :erlang.read_timer(ref)
      r != false and r != 0
    else
      false
    end
  end

  def get_timer(name) do
    ref = Process.get name
    if is_reference(ref) do
      r = :erlang.read_timer(ref)
      if is_integer(r), do: r, else: 0
    else
      0
    end
  end

  def reset_timer(name, msg, timeout) do
    ref0 = Process.delete name
    if is_reference(ref0) do
      :erlang.cancel_timer(ref0)
    end
    receive do
      ^msg -> :ok
    after
      0 -> :ok
    end
    ref = :erlang.send_after(timeout, self(), msg)
    Process.put name, ref
  end

  def dict_counter(name, incr) do
    ct = if incr == :reset do
      0
    else
      Process.get(name, 0) + incr
    end
    Process.put name, ct
    ct
  end

  def dict_timestamp_check(name, duration) do
    ts_now = System.system_time(:millisecond)
    ts_name = Process.get(name, 0)
    if ts_now - ts_name > duration do
      Process.put(name, ts_now)
      true
    else
      false
    end
  end

  def save_proc_opt(opt) do
    cond do
      is_list(opt) ->
        Process.put :proc_opts, :maps.from_list(opt)
      is_map(opt) ->
        Process.put :proc_opts, opt
      true ->
        opt
    end
  end

  def check_ipv4(ip) when is_binary(ip) do
    check_ipv4(:erlang.binary_to_list(ip))
  end

  def check_ipv4(ip) when is_list(ip) do
    case :inet.parse_ipv4strict_address(ip) do
      {:ok, addr} ->
        check_ipv4(addr)
      {:error, _} ->
        false
    end
  end

  def check_ipv4({a, b, _c, _d}) do
    if (a == 127) or (a == 10) or (a == 172 and (b >= 0 and b <= 31)) or (a == 192 and b == 168) do
      {true, :private}
    else
      {true, :public}
    end
  end

  def check_ipv4(_) do
    false
  end
end