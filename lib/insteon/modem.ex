defmodule Insteon.Modem do
  use GenServer
  require IEx
  
  # Insteon modem configuration
  @port_options [speed: 19200, flow_control: :none]

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

    {:ok, {pid, [], ""}}
  end

  # Close the port
  def close(pid) do
    Nerves.UART.close(pid)
  end

  # Handle error received from the serial port
  def handle_info({:nerves_uart, _, {:error, reason}}, {pid, _, _}) do
    {:stop, reason, {pid, ""}}
  end

  # Handle data received from the serial port
  def handle_info({:nerves_uart, _, data}, {pid, receivers, buffer}) do
    {messages, tail} = Insteon.Parser.parse_messages(buffer <> data)
    receivers = handle_messages(messages, receivers)

    {:noreply, {pid, receivers, tail}}
  end

  def handle_call({type, message}, from, {pid, receivers, buff}) do
    :ok = Nerves.UART.write(pid, message)
    {:noreply, {pid, [{type, from} | receivers], buff}}
  end

  def get_info(pid) do
    GenServer.call(pid, {:get_im_info, <<0x02, 0x60>>})
  end

  defp handle_messages([], receivers), do: receivers
  defp handle_messages([{type, _} = m | tail], receivers) do
    receivers =
      case Keyword.pop_first(receivers, type) do
        {nil, rs} -> rs
        {pid, rs} ->
          GenServer.reply(pid, m)
          rs
      end

    # Handle a push message
    handle_messages(tail, receivers)
  end
end
