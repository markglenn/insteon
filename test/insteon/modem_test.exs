defmodule Insteon.ModemTest do
  alias Insteon.Modem

  use ExUnit.Case, async: true

  doctest Insteon.Modem

  test "handles new data from serial port" do
    assert Modem.handle_info({:nerves_uart, self(), <<0x02, 0x03>>}, {nil, <<0x01>>}) ==
      {:noreply, {nil, <<0x01, 0x02, 0x03>>}}
  end

  test "handles error from serial port" do
    pid = self()
    assert Modem.handle_info({:nerves_uart, pid, {:error, "Failed"}}, {pid, <<0x01>>}) ==
      {:stop, "Failed", {pid, <<>>}}
  end
end

