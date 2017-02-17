defmodule Insteon.ParserTest do
  alias Insteon.Parser

  use ExUnit.Case, async: true

  describe "parse_messages" do
    test "parses incomplete message" do
      assert {[], <<0x02>>} == Parser.parse_messages(<<0x02>>)
    end

    test "parses single message" do
      {[_], <<0x02>>} = Parser.parse_messages(<<0x02, 0x65, 0x06, 0x02>>)
    end

    test "parses multiple messages" do
      {[_, _], <<0x02>>} = Parser.parse_messages(<<0x02, 0x65, 0x06, 0x02, 0x65, 0x15, 0x02>>)
    end

    test "parses single message with no extra data" do
      {[_], ""} = Parser.parse_messages(<<0x02, 0x65, 0x06>>)
    end
  end

  test "Incomplete message received" do
    assert {nil, <<0x02>>} == Parser.parse(<<0x02>>)
  end

  test "0x50 - Standard message received" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x50, 0x01, 0x02, 0x03, 0x11, 0x12, 0x13, 0x01, 0x02, 0x03, 0xFF>>)
    assert message == {
      :standard_message,
      %{
        from: <<1, 2, 3>>,
        to: <<17, 18, 19>>,
        flags: 1,
        command1: 2,
        command2: 3
      }
    }
  end

  test "0x51 - Extended message received" do
    {message, <<0xFF>>} = Parser.parse(
      <<0x02, 0x51, 0x01, 0x02, 0x03, 0x11, 0x12, 0x13, 0x01, 0x02, 0x03,
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0xFF>>)

    assert message == {
      :extended_message,
      %{
        from: <<1, 2, 3>>,
        to: <<17, 18, 19>>,
        flags: 1,
        command1: 2,
        command2: 3,
        user_data: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14>>
      }
    }
  end

  test "0x52 - X10 Received" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x52, 0x01, 0x02, 0xFF>>)

    assert message == {
      :x10_received,
      %{
        raw_x10: 0x01,
        flags: 0x02
      }
    }
  end

  test "0x53 - All-Linking Completed" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x53, 3, 4, 5, 6, 7, 8, 9, 0xFF, 0xFF>>)

    assert message == {
      :all_linking_completed,
      %{ link_code: 3, group: 4, device_id: <<5, 6, 7>>, device_category: 8,
        device_subcategory: 9, firmware_version: 0xFF }
    }
  end

  test "0x54 - Button Event Reported" do
    assert {{:button_event_reported, %{button: :set, event: :pressed}}, <<0xFF>>} ==
      Parser.parse(<<0x02, 0x54, 0x02, 0xFF>>)
    assert {{:button_event_reported, %{button: :set, event: :held}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x03>>)
    assert {{:button_event_reported, %{button: :set, event: :released}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x04>>)

    assert {{:button_event_reported, %{button: :button1, event: :pressed}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x12>>)
    assert {{:button_event_reported, %{button: :button1, event: :held}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x13>>)
    assert {{:button_event_reported, %{button: :button1, event: :released}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x14>>)

    assert {{:button_event_reported, %{button: :button2, event: :pressed}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x22>>)
    assert {{:button_event_reported, %{button: :button2, event: :held}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x23>>)
    assert {{:button_event_reported, %{button: :button2, event: :released}}, <<>>} ==
      Parser.parse(<<0x02, 0x54, 0x24>>)
  end

  test "0x55 - User Reset Detected" do
    assert {{:user_reset_detected, %{}}, <<0xFF>>} == Parser.parse(<<0x02, 0x55, 0xFF>>)
  end

  test "0x56 - All-Link Cleanup Failure Report" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x56, 0x01, 4, 5, 6, 7, 0xFF>>)

    assert message == {
      :all_link_cleanup_failure_report,
      %{
        reason: :no_ack,
        group: 4,
        device_id: <<5, 6, 7>>
      }
    }
  end

  test "0x57 - All-Link Record Response" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x57, 0xC2, 4, 5, 6, 7, 8, 9, 10, 0xFF>>)

    assert message == {
      :all_link_record_response,
      %{
        type: :controller,
        group: 4,
        device_id: <<5, 6, 7>>,
        link_data: <<8, 9, 10>>
      }
    }

    # Also test responder flag
    {{_, %{type: :responder}}, <<>>} = Parser.parse(<<0x02, 0x57, 0x82, 4, 5, 6, 7, 8, 9, 10>>)
  end

  test "0x58 - ALL-Link Cleanup Status Report" do
    assert {{:all_link_cleanup_status_report, %{status: :ack}}, <<0xFF>>} == Parser.parse(<<0x02, 0x58, 0x06, 0xFF>>)
    assert {{:all_link_cleanup_status_report, %{status: :nack}}, <<0xFF>>} == Parser.parse(<<0x02, 0x58, 0x15, 0xFF>>)
  end

  test "0x60 - Get IM Info" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x60, 3, 4, 5, 6, 7, 8, 0x06, 0xFF>>)

    assert message == {
      :get_im_info,
      %{
        device_id: <<3, 4, 5>>,
        device_category: 6,
        device_subcategory: 7,
        firmware_version: 8,
        status: :ack
      }
    }
  end

  test "0x61 - Send ALL-Link Command" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x61, 3, 4, 5, 0x06, 0xFF>>)

    assert message == {
      :send_all_link_command,
      %{
        group: 3,
        command: 4,
        command2: 5,
        status: :ack
      }
    }
  end

  test "0x62 - Insteon Standard Length Message" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x62, 3, 4, 5, 6, 7, 8, 0x06, 0xFF>>)

    assert message == {
      :insteon_message_response,
      %{
        to: <<3, 4, 5>>,
        flags: 6,
        command1: 7,
        command2: 8,
        status: :ack
      }
    }
  end

  test "0x62 - Insteon Extended Length Message" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x62, 3, 4, 5, 0x16, 7, 8,
                                       1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
                                       0x06, 0xFF>>)

    assert message == {
      :insteon_message_response,
      %{
        to: <<3, 4, 5>>,
        flags: 0x16,
        command1: 7,
        command2: 8,
        status: :ack,
        user_data: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14>>
      }
    }
  end

  test "0x63 - Send X10" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x63, 3, 4, 0x06, 0xFF>>)

    assert message == { :send_x10, %{ raw_x10: 3, flags: 4, status: :ack } }
    assert {{_, %{status: :nack}}, _} = Parser.parse(<<0x02, 0x63, 3, 4, 0x15>>)
  end

  test "0x64 - Start ALL-Linking" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x64, 3, 4, 0x06, 0xFF>>)

    assert message == { :start_all_linking, %{ code: 3, group: 4, status: :ack } }
    assert {{_, %{status: :nack}}, _} = Parser.parse(<<0x02, 0x63, 3, 4, 0x15>>)
  end

  test "0x65 - Cancel ALL-Linking" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x65, 0x06, 0xFF>>)

    assert message == { :cancel_all_linking, %{ status: :ack } }
    assert {{_, %{status: :nack}}, _} = Parser.parse(<<0x02, 0x65, 0x15>>)
  end

  test "0x66 - Set Host Device Category" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x66, 3, 4, 0xFF, 0x06, 0xFF>>)
    assert message == { :set_host_device_category, %{ category: 3, subcategory: 4, firmware_version: 0xFF, status: :ack } }
  end

  test "0x67 - Reset the IM" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x67, 0x06, 0xFF>>)
    assert message == { :reset_the_im, %{ status: :ack } }
  end

  test "0x68 - Set Insteon ACK Message Byte" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x68, 3, 0x06, 0xFF>>)
    assert message == { :set_insteon_ack_message_byte, %{ command2: 3, status: :ack } }
  end

  test "0x69 - Get First ALL-Link Record" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x69, 0x06, 0xFF>>)
    assert message == { :get_first_all_link_record, %{ status: :ack } }
  end

  test "0x6A - Get Next ALL-Link Record" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x6A, 0x06, 0xFF>>)
    assert message == { :get_next_all_link_record, %{ status: :ack } }
  end

  test "0x6B - Set IM Configuration" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x6B, 1, 0x06, 0xFF>>)
    assert message == { :set_im_configuration, %{ flags: 1, status: :ack } }
  end

  test "0x6C - Get ALL-Link Record for Sender" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x6C, 0x06, 0xFF>>)
    assert message == { :get_all_link_record_for_sender, %{ status: :ack } }
  end

  test "0x6D - LED On" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x6D, 0x06, 0xFF>>)
    assert message == { :led_on, %{ status: :ack } }
  end

  test "0x6E - LED Off" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x6E, 0x06, 0xFF>>)
    assert message == { :led_off, %{ status: :ack } }
  end

  test "0x6F - Manage ALL-Link Record" do
    {message, <<0xFF>>} = Parser.parse(<<0x02, 0x6F, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0x06, 0xFF>>)
    assert message == {
      :manage_all_link_record,
      %{
        control_code: 3,
        flags: 4,
        group: 5,
        id: <<6, 7, 8>>,
        data: <<9, 10, 11>>,
        status: :ack
      }
    }
  end
end

