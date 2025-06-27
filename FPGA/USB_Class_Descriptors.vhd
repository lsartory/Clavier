-- Clavier | USB_Class_Descriptors.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;
use work.usb_descriptors.all;

--------------------------------------------------

package usb_class_descriptors is
    --constant NO_USB_CLASSES: usb_byte_array_t(2 to 1) := (others => "");

    --------------------------------------------------

    -- Human Interface Device class descriptor
    type usb_hid_sub_descriptor_t is record
        bDescriptorType:   usb_byte_t;
        wDescriptorLength: usb_word_t;
    end record;
    type usb_hid_sub_descriptor_array_t is array(natural range <>) of usb_hid_sub_descriptor_t;

    function from_report_descriptor(desc: usb_byte_array_t) return usb_hid_sub_descriptor_t;

    type usb_hid_class_descriptor_t is record
        header:          usb_descriptor_header_t;
        bcdHID:          usb_word_t;
        bCountryCode:    usb_byte_t;
        bNumDescriptors: usb_byte_t;
        sub_descriptors: usb_hid_sub_descriptor_array_t(0 to 3);
    end record;

    constant EMPTY_USB_HID_CLASS_DESCRIPTOR: usb_hid_class_descriptor_t := (
        header          => EMPTY_USB_DESCRIPTOR_HEADER,
        bcdHID          => (others => '0'),
        bCountryCode    => (others => '0'),
        bNumDescriptors => (others => '0'),
        sub_descriptors => (others => (others => (others => '0')))
    );

    function new_usb_hid_class(
        country_code:    integer range 0 to 255;
        sub_descriptors: usb_hid_sub_descriptor_array_t
    ) return usb_hid_class_descriptor_t;

    function to_byte_array(d: usb_hid_class_descriptor_t) return usb_byte_array_t;

    --------------------------------------------------

    -- Communication Device Class descriptor
    type usb_cdc_class_descriptor_t is record
        header: usb_descriptor_header_t;
        -- TODO: not implemented yet
    end record;

    constant EMPTY_USB_CDC_CLASS_DESCRIPTOR: usb_cdc_class_descriptor_t := (
        header => EMPTY_USB_DESCRIPTOR_HEADER
        -- TODO: not implemented yet
    );

end package;

--------------------------------------------------

package body usb_class_descriptors is
    -- Create a new USB HID class sub-descriptor from a report descriptor byte array
    function from_report_descriptor(desc: usb_byte_array_t) return usb_hid_sub_descriptor_t is
        variable ret: usb_hid_sub_descriptor_t;
    begin
        ret.bDescriptorType   := x"22";
        ret.wDescriptorLength := usb_word_t(to_unsigned(desc'length, ret.wDescriptorLength'length));
        return ret;
    end function;

    -- Create a new USB HID class descriptor
    function new_usb_hid_class(
        country_code:    integer range 0 to 255;
        sub_descriptors: usb_hid_sub_descriptor_array_t
    ) return usb_hid_class_descriptor_t is
        variable ret: usb_hid_class_descriptor_t := EMPTY_USB_HID_CLASS_DESCRIPTOR;
    begin
        ret.header.bLength         := x"06"; -- Length without sub-descriptors
        ret.header.bDescriptorType := x"21";

        ret.bcdHID          := x"0111"; -- HID 1.11
        ret.bCountryCode    := usb_byte_t(to_unsigned(country_code,           ret.bCountryCode'length));
        ret.bNumDescriptors := usb_byte_t(to_unsigned(sub_descriptors'length, ret.bNumDescriptors'length));

        for i in sub_descriptors'low to sub_descriptors'high loop
            ret.header.bLength := usb_byte_t(unsigned(ret.header.bLength) + 3);
            ret.sub_descriptors(i - sub_descriptors'low) := sub_descriptors(i);
        end loop;

        return ret;
    end function;

    -- Convert an HID class descriptor into a byte array
    function to_byte_array(d: usb_hid_class_descriptor_t) return usb_byte_array_t is
        variable ret: usb_byte_array_t(0 to to_integer(unsigned(d.header.bLength)) - 1) := (others => (others => '0'));
    begin
        ret(0) := d.header.bLength;
        ret(1) := d.header.bDescriptorType;
        ret(2) := d.bcdHID( 7 downto 0);
        ret(3) := d.bcdHID(15 downto 8);
        ret(4) := d.bCountryCode;
        ret(5) := d.bNumDescriptors;

        for i in d.sub_descriptors'low to d.sub_descriptors'high loop
            if unsigned(d.sub_descriptors(i).bDescriptorType) = 0 then
                exit;
            end if;
            ret(6 + 3 * (i - d.sub_descriptors'low)) := d.sub_descriptors(i).bDescriptorType;
            ret(7 + 3 * (i - d.sub_descriptors'low)) := d.sub_descriptors(i).wDescriptorLength( 7 downto 0);
            ret(8 + 3 * (i - d.sub_descriptors'low)) := d.sub_descriptors(i).wDescriptorLength(15 downto 8);
        end loop;

        return ret;
    end function;
end package body;
