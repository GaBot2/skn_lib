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
          reset_id(:proxy_auth_seq, 1)
      end
      id
  end

  def reset_id(key, value) do
      Skn.Counter.write(key, value)
      set(key, value)
  end

end


defmodule Skn.Counter do
  @def_threshold  5_000_000_000
  @table :skn_counter
  def ensure_init() do
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

  def update_counter(name, incr) do
    :ets.update_counter(@table, name, {2, incr, @def_threshold, 1}, {name, incr})
  end
end
