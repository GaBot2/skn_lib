defmodule Skn.Log do
    defmacro warn(chardata_or_fun, metadata \\ []) do
        quote do
            if Process.get(:debug, false) == true do
                Logger.warning(unquote(chardata_or_fun), unquote(metadata))
            end
        end
    end

    defmacro error(chardata_or_fun, metadata \\ []) do
        quote do
            Logger.error(unquote(chardata_or_fun), unquote(metadata))
        end
    end

    defmacro trace(chardata_or_fun, metadata \\ []) do
        quote do
            if Process.get(:debug, false) == true do
                Logger.error(unquote(chardata_or_fun), unquote(metadata))
            end
        end
    end

    defmacro info(chardata_or_fun, metadata \\ []) do
        quote do
            if Process.get(:debug, false) == true do
                Logger.info(unquote(chardata_or_fun), unquote(metadata))
            end
        end
    end

    defmacro debug(chardata_or_fun, metadata \\ []) do
        quote do
            if Process.get(:debug, false) == true do
                Logger.debug(unquote(chardata_or_fun), unquote(metadata))
            end
        end
    end
end
