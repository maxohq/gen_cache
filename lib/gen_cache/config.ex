defmodule GenCache.Config do
  def set_log_level(level) do
    Logger.put_module_level(GenCache, level)
  end

  def log_debug() do
    Logger.put_module_level(GenCache, :debug)
  end

  def log_info() do
    Logger.put_module_level(GenCache, :info)
  end
end
