defmodule Insteon.Parser do
  use Bitwise

  # 0x50 - Standard Message Received
  def parse(<<0x02, 0x50, body :: binary-size(9), tail :: binary>>) do
    <<from :: binary-size(3), to :: binary-size(3), flags, command1, command2>> = body

    {
      {
        :standard_message,
        %{
          from: from,
          to: to,
          flags: flags,
          command1: command1,
          command2: command2
        }
      }, tail
    }
  end

  # 0x51 - Extended Message Received
  def parse(<<0x02, 0x51, body :: binary-size(23), tail :: binary>>) do
    <<from :: binary-size(3), to :: binary-size(3), flags, command1, command2, user_data :: binary-size(14)>> = body

    {
      {
        :extended_message,
        %{
          from: from,
          to: to,
          flags: flags,
          command1: command1,
          command2: command2,
          user_data: user_data
        }
      }, tail
    }
  end

  # 0x52 - X10 Received
  def parse(<<0x02, 0x52, raw_x10, flags, tail :: binary>>) do
    {
      { :x10_received, %{raw_x10: raw_x10, flags: flags} },
      tail
    }
  end

  # 0x53 - All-Linking Completed
  def parse(<<0x02, 0x53, link_code, group, device_id :: binary-size(3), device_category, device_subcategory, firmware_version, tail :: binary>>) do
    {
      {
        :all_linking_completed,
        %{
          link_code: link_code,
          group: group,
          device_id: device_id,
          device_category: device_category,
          device_subcategory: device_subcategory,
          firmware_version: firmware_version
        }
      },
      tail
    }
  end

  # 0x54 - Button Event Reported
  def parse(<<0x02, 0x54, event, tail :: binary>>) do
    button = case event >>> 4 do
      0 -> :set
      1 -> :button1
      2 -> :button2
    end

    action = case event &&& 0xF do
      2 -> :pressed
      3 -> :held
      4 -> :released
    end

    {
      {
        :button_event_reported,
        %{ button: button, event: action }
      },
      tail
    }
  end

  # 0x55 - User Reset Detected
  def parse(<<0x02, 0x55, tail :: binary>>), do: {{:user_reset_detected, %{}}, tail}

  # 0x56 - All-Link Cleanup Failure Report
  def parse(<<0x02, 0x56, 0x01, group, device_id :: binary-size(3), tail :: binary>>) do
    {
      {
        :all_link_cleanup_failure_report,
        %{
          reason: :no_ack,
          group: group,
          device_id: device_id
        }
      },
      tail
    }
  end

  # 0x57 - All-Link Record Response
  def parse(<<0x02, 0x57, flags, group, device_id :: binary-size(3), link_data :: binary-size(3), tail :: binary>>) do
    im_type = case flags &&& 0x40 do
      0x00 -> :responder
      0x40 -> :controller
    end

    {
      {
        :all_link_record_response,
        %{
          type: im_type,
          group: group,
          device_id: device_id,
          link_data: link_data
        }
      },
      tail
    }
  end

  # 0x58 - ALL-Link Cleanup Status Report
  def parse(<<0x02, 0x58, ack, tail :: binary>>), do: {{:all_link_cleanup_status_report, %{status: status(ack)}}, tail}

  # 0x60 - Get IM Info
  def parse(<<0x02, 0x60, body :: binary-size(7), tail :: binary>>) do
    <<device_id :: binary-size(3), device_category, device_subcategory, firmware_version, ack>> = body

    {
      {
        :get_im_info,
        %{
          device_id: device_id,
          device_category: device_category,
          device_subcategory: device_subcategory,
          firmware_version: firmware_version,
          status: status(ack)
        }
      }, tail
    }
  end

  # 0x61 - Send ALL-Link Command
  def parse(<<0x02, 0x61, group, command, command2, ack, tail :: binary>>) do
    {
      {
        :send_all_link_command,
        %{
          group: group,
          command: command,
          command2: command2,
          status: status(ack)
        }
      },
      tail
    }
  end

  # 0x62 - Send INSTEON Standard-length Message
  def parse(<<0x02, 0x62, to :: binary-size(3), flags, command1, command2, ack, tail :: binary>>)
      when (flags &&& 0x10) == 0 do
    {
      {
        :insteon_message_response,
        %{ to: to, flags: flags, command1: command1, command2: command2, status: status(ack) }
      },
      tail
    }
  end
  
  # 0x62 - Send INSTEON Extended-length Message
  def parse(<<0x02, 0x62, to :: binary-size(3), flags, command1, command2, user_data :: binary-size(14), ack, tail :: binary>>)
      when (flags &&& 0x10) == 0x10 do
    {
      {
        :insteon_message_response,
        %{ to: to, flags: flags, command1: command1, command2: command2, status: status(ack), user_data: user_data }
      },
      tail
    }
  end

  def parse(<<0x02, 0x63, raw_x10, flags, ack, tail :: binary>>) do
    {
      {
        :send_x10,
        %{ raw_x10: raw_x10, flags: flags, status: status(ack) }
      },
      tail
    }
  end

  # Incomplete message
  def parse(<<0x02, _ :: binary>> = msg) do
    { nil, msg }
  end

  defp status(0x06), do: :ack
  defp status(0x15), do: :nack
end

