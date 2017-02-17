defmodule Insteon.Modem do
  use GenServer
  
  # Insteon modem configuration
  @port_options %{speed: 19200, flow_control: :none}

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # Determine the connected port
    port =
      Nerves.UART.enumerate
      |> Map.keys
      |> Enum.find(fn(p) -> Regex.match?(~r/usbserial/, p) end)

    {:ok, pid} = Nerves.UART.start_link

    :ok = Nerves.UART.open(pid, port, @port_options)

    {:ok, {pid, ""}}
  end

  # Close the port
  def close(pid) do
    Nerves.UART.close(pid)
  end

  # Handle error received from the serial port
  def handle_info({:nerves_uart, _, {:error, reason}}, {pid, _}) do
    {:stop, reason, {pid, ""}}
  end

  # Handle data received from the serial port
  def handle_info({:nerves_uart, _, data}, {pid, buffer}) do
    {:noreply, {pid, buffer <> data}}
  end
end
