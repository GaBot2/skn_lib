defmodule Skn.Config do
  require Record

  @default_seq_max 9_999_999_000
  @skn_config_fields [key: :nil, value: :nil]
  Record.defrecord :skn_config, @skn_config_fields

  def fields(x) do
      Keyword.keys x
  end

  def create_table() do
      :mnesia.create_table(:skn_config,[disc_copies: [node()], record_name: :skn_config, attributes: fields(@skn_config_fields)])
  end


  def get(key, default \\ nil) do
    case Process.get(:proc_opts, nil) do
      v when is_map(v) ->
        Map.get(v, key, default)
      _ ->
        case :mnesia.dirty_read(:skn_config, key) do
          [c | _] -> skn_config(c, :value)
          _ -> default
        end
    end
  end

  def delete(key) do
    :mnesia.dirty_delete(:skn_config, key)
  end

  def set_if(key, value) do
    case get(key, nil) do
      nil -> set(key, value)
      _ -> :ignore
    end
  end

  def set(key, value) do
    obj = skn_config(key: key, value: value)
    :mnesia.dirty_write(:skn_config, obj)
  end

  def set_tranc(key, value) do
    f = fn ->
      obj = skn_config(key: key, value: value)
      :mnesia.write(:skn_config, obj, :write)
    end
    :mnesia.transaction(f)
  end

  def load_config(reset_keys\\ [:farmer_max_id, :farmer_min_id]) do
    priv = :os.getenv('CONFIG_FILE', './priv/fifa.config')
    {:ok, ret} = :file.consult priv
    Enum.each ret, fn {k, v} ->
      if k in reset_keys do
        reset_id(k, v)
      else
        set(k, v)
      end
    end
  end

  def load_id_seq(keys\\ [:proxy_auth_seq, :worker_seq, :proxy_super_seq, :proxy_super_seq2, :farmer_max_id, :bot_id_seq]) do
      Enum.each keys, fn x ->
          v = get(x, 0)
          reset_id(x, v)
      end
      :ok
  end

  def store_id_seq(keys\\ [:proxy_auth_seq, :worker_seq, :proxy_super_seq, :proxy_super_seq2, :farmer_max_id, :bot_id_seq]) do
      Enum.each keys, fn x ->
          v = Skn.Counter.read(x)
          set_tranc(x, v)
      end
      :ok
  end

  def gen_id(key, threshold\\ @default_seq_max) do
      id = Skn.Counter.update_counter(key, 1)
      if id > threshold do
          reset_id(key, 1)
      end
      id
  end

  def reset_id(key, value) do
      Skn.Counter.write(key, value)
      set(key, value)
  end

end


defmodule Skn.Counter do
  use GenServer
  require Logger
  @name :skn_counter
  @def_threshold  5_000_000_000
  @table :skn_counter
  def create_db() do
    case :ets.info(@table) do
      :undefined ->
        :ets.new( @table, [:public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])
      _ ->
        :ok
    end
  end

  def read(name) do
    case :ets.lookup(@table, name) do
      [{_, value}] -> value
      _ -> 0
    end
  end

  def write(name, v) do
    :ets.insert(@table, {name, v})
  end

  def read_and_reset(name) do
    case :ets.update_counter(@table, name, [{2, 0}, {2, 0, 0, 0}], {name, 0}) do
      [v | _] -> v
      _ -> 0
    end
  end

  def delete(name) do
    :ets.delete(@table, name)
  end

  def update_counter(name, incr, threshold\\ @def_threshold) do
    :ets.update_counter(@table, name, {2, incr, threshold, 1}, {name, 0})
  end

  def check_avg_min_max(name) do
    is_avg_mix_max = String.contains?(name, "_avg") or String.contains?(name, "_min") or String.contains?(name, "_max")
    if is_avg_mix_max do
      len = byte_size(name)
      base = String.slice(name, 0, len - 4)
      nk = :erlang.binary_to_existing_atom(name, :latin1)
      os = Enum.reduce(["_avg", "_min", "_max"], [], fn(x, acc) ->
        xx = base <> x
        if xx != name do
          [:erlang.binary_to_existing_atom(xx, :latin1)| acc]
        else
          acc
        end
      end)
      {true, nk, os, :erlang.binary_to_existing_atom(base <> "_count", :latin1)}
    else
      {false, :erlang.binary_to_existing_atom(name, :latin1)}
    end
  end

  def read_avg_min_max(name, others, count) do
    case Process.whereis(@name) do
      nil ->
        0
      pid ->
        GenServer.call(pid, {:read_avg_min_max, name, others, count})
    end
  end

  def run_async(fun) do
    GenServer.cast(@name, {:run, fun})
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call({:read_avg_min_max, name, others, count}, _from, state) do
    try do
      v = read({name, :save})
      ret= if v == 0 do
        read_and_reset(count)
        Enum.each others, fn x ->
          vx = read({x, :save})
          vx = if vx != 0, do: vx, else: read_and_reset(x)
          write({x, :save}, vx)
        end
        read_and_reset(name)
      else
        delete({name, :save})
        v
      end
      {:reply, ret, state}
    catch
      _, exp ->
        Logger.error("read_avg_min_max => #{inspect exp}, #{inspect System.stacktrace()}")
        {:reply, 0, state}
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :badreq}, state}
  end

  def handle_cast({:run, fun}, state) do
    try do
      if is_function(fun) do
        fun.()
      else
        :ok
      end
    catch
      _, exp ->
        Logger.error("run => #{inspect exp}, #{inspect System.stacktrace()}")
        :ignore
    end
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    Logger.error("drop #{inspect(msg)}")
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.error("drop #{inspect(info)}")
    {:noreply, state}
  end

  def code_change(_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.debug("stop by #{inspect(reason)}")
    :ok
  end

end
