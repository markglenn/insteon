defmodule Insteon do
  @moduledoc """
  Documentation for Insteon.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Insteon.hello
      :world

  """
  def hello do
    {:ok, pid} = Insteon.Modem.start_link

    Insteon.Modem.get_info(pid)
  end
end
