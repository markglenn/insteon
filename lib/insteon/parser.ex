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
  def parse(<<0x02, 0x58, ack, tail :: binary>>) do
    {
      {
        :all_link_cleanup_status_report,
        %{status: status(ack)}
      },
      tail
    }
  end


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

  # 0x63 - Send X10 
  def parse(<<0x02, 0x63, raw_x10, flags, ack, tail :: binary>>) do
    {
      {
        :send_x10,
        %{ raw_x10: raw_x10, flags: flags, status: status(ack) }
      },
      tail
    }
  end

  @doc """
  0x64 - Start ALL-Linking

  What it does:         Puts the IM into ALL-Linking mode without using the SET Button
  What you send:        4 bytes.
  What you'll get back: 5 bytes for this Command response and then an additional 10 bytes in
                        an ALL- Linking Completed message once a successful ALL-Link has
                        been established.
  LED indication:       The LED will blink continuously at a rate of 1⁄2 second on and 1⁄2
                        second off until the ALL-Link is completed or canceled.
  Related Commands:     IM 0x53 ALL-Linking Completed
                        IM 0x65 Cancel ALL-Linking
  """
  def parse(<<0x02, 0x64, code, group, ack, tail :: binary>>) do
    {
      {
        :start_all_linking,
        %{ code: code, group: group, status: status(ack) }
      },
      tail
    }
  end

  @doc """
  0x65 - Cancel ALL-Linking

  What it does:         Cancels the ALL-Linking process that was started either by holding
                        down the IM’s SET Button or by sending a Start ALL-Linking Command
                        to the IM.
  What you send:        2 bytes.
  What you'll get back: 3 bytes.
  LED indication:       The LED will stop blinking.
  Related Commands:     IM 0x64 Start ALL-Linking
                        IM 0x54 Button Event Report
  """
  def parse(<<0x02, 0x65, ack, tail :: binary>>) do
    { { :cancel_all_linking, %{ status: status(ack) } }, tail }
  end

  # 0x66 - Set Host Device Category 
  def parse(<<0x02, 0x66, category, subcategory, firmware_version, ack, tail :: binary>>) do
    {
      {
        :set_host_device_category,
        %{
          category: category,
          subcategory: subcategory,
          firmware_version: firmware_version,
          status: status(ack)
        }
      },
      tail
    }
  end

  # 0x67 - Reset the IM
  def parse(<<0x02, 0x67, ack, tail :: binary>>) do
    { { :reset_the_im, %{ status: status(ack) } }, tail }
  end

  # 0x68 - Set Insteon ACK Message Byte
  def parse(<<0x02, 0x68, command2, ack, tail :: binary>>) do
    { { :set_insteon_ack_message_byte, %{ command2: command2, status: status(ack) } }, tail }
  end

  # 0x69 - Get First ALL-Link Record
  def parse(<<0x02, 0x69, ack, tail :: binary>>) do
    { { :get_first_all_link_record, %{ status: status(ack) } }, tail }
  end

  # 0x6A - Get Next ALL-Link Record
  def parse(<<0x02, 0x6A, ack, tail :: binary>>) do
    { { :get_next_all_link_record, %{ status: status(ack) } }, tail }
  end

  # 0x6B - Set IM Configuration
  def parse(<<0x02, 0x6B, flags, ack, tail :: binary>>) do
    { { :set_im_configuration, %{ flags: flags, status: status(ack) } }, tail }
  end

  # 0x6C - Get ALL-Link Record for Sender
  def parse(<<0x02, 0x6C, ack, tail :: binary>>) do
    { { :get_all_link_record_for_sender, %{ status: status(ack) } }, tail }
  end

  # 0x6D - LED On
  def parse(<<0x02, 0x6D, ack, tail :: binary>>) do
    { { :led_on, %{ status: status(ack) } }, tail }
  end

  # 0x6E - LED Off
  def parse(<<0x02, 0x6E, ack, tail :: binary>>) do
    { { :led_off, %{ status: status(ack) } }, tail }
  end

  # 0x6F - Manage ALL-Link Record
  def parse(<<0x02, 0x6F, control_code, flags, group, id :: binary-size(3), data :: binary-size(3), ack, tail :: binary>>) do
    {
      {
        :manage_all_link_record,
        %{
          control_code: control_code,
          flags: flags,
          group: group,
          id: id,
          data: data,
          status: status(ack)
        }
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

