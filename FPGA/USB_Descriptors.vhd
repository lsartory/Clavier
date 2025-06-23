-- Clavier | USB_Descriptors.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;

--------------------------------------------------

package usb_descriptors is
    type usb_device_descriptor_t is record
        bLength:            usb_byte_t;
        bDescriptorType:    usb_byte_t;
        bcdUSB:             usb_word_t;
        bDeviceClass:       usb_byte_t;
        bDeviceSubClass:    usb_byte_t;
        bDeviceProtocol:    usb_byte_t;
        bMaxPacketSize:     usb_byte_t;
        idVendor:           usb_word_t;
        idProduct:          usb_word_t;
        bcdDevice:          usb_word_t;
        iManufacturer:      usb_byte_t;
        iProduct:           usb_byte_t;
        iSerialNumber:      usb_byte_t;
        bNumConfigurations: usb_byte_t;
    end record;
    function serialize_usb_device_descriptor(d: usb_device_descriptor_t; i: natural) return usb_byte_t;

    type usb_configuration_descriptor_t is record
        bLength:             usb_byte_t;
        bDescriptorType:     usb_byte_t;
        wTotalLength:        usb_word_t;
        bNumInterfaces:      usb_byte_t;
        bConfigurationValue: usb_byte_t;
        iConfiguration:      usb_byte_t;
        bmAttributes:        usb_byte_t;
        bMaxPower:           usb_byte_t;
    end record;
    function serialize_usb_configuration_descriptor(d: usb_configuration_descriptor_t; i: natural) return usb_byte_t;

    type usb_interface_descriptor_t is record
        bLength:            usb_byte_t;
        bDescriptorType:    usb_byte_t;
        bInterfaceNumber:   usb_byte_t;
        bAlternateSetting:  usb_byte_t;
        bNumEndpoints:      usb_byte_t;
        bInterfaceClass:    usb_byte_t;
        bInterfaceSubClass: usb_byte_t;
        bInterfaceProtocol: usb_byte_t;
        iInterface:         usb_byte_t;
    end record;
    function serialize_usb_interface_descriptor(d: usb_interface_descriptor_t; i: natural) return usb_byte_t;

    type usb_endpoint_descriptor_t is record
        bLength:          usb_byte_t;
        bDescriptorType:  usb_byte_t;
        bEndpointAddress: usb_byte_t;
        bmAttributes:     usb_byte_t;
        wMaxPacketSize:   usb_word_t;
        bInterval:        usb_byte_t;
    end record;
    function serialize_usb_endpoint_descriptor(d: usb_endpoint_descriptor_t; i: natural) return usb_byte_t;
end package;

--------------------------------------------------

package body usb_descriptors is
    function serialize_usb_device_descriptor(d: usb_device_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when  0 => ret := d.bLength;
            when  1 => ret := d.bDescriptorType;
            when  2 => ret := d.bcdUSB( 7 downto 0);
            when  3 => ret := d.bcdUSB(15 downto 8);
            when  4 => ret := d.bDeviceClass;
            when  5 => ret := d.bDeviceSubClass;
            when  6 => ret := d.bDeviceProtocol;
            when  7 => ret := d.bMaxPacketSize;
            when  8 => ret := d.idVendor( 7 downto 0);
            when  9 => ret := d.idVendor(15 downto 8);
            when 10 => ret := d.idProduct( 7 downto 0);
            when 11 => ret := d.idProduct(15 downto 8);
            when 12 => ret := d.bcdDevice( 7 downto 0);
            when 13 => ret := d.bcdDevice(15 downto 8);
            when 14 => ret := d.iManufacturer;
            when 15 => ret := d.iProduct;
            when 16 => ret := d.iSerialNumber;
            when 17 => ret := d.bNumConfigurations;
            when others => null;
        end case;
        return ret;
    end function;

    function serialize_usb_configuration_descriptor(d: usb_configuration_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.bLength;
            when 1 => ret := d.bDescriptorType;
            when 2 => ret := d.wTotalLength( 7 downto 0);
            when 3 => ret := d.wTotalLength(15 downto 8);
            when 4 => ret := d.bNumInterfaces;
            when 5 => ret := d.bConfigurationValue;
            when 6 => ret := d.iConfiguration;
            when 7 => ret := d.bmAttributes;
            when 8 => ret := d.bMaxPower;
            when others => null;
        end case;
        return ret;
    end function;

    function serialize_usb_interface_descriptor(d: usb_interface_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.bLength;
            when 1 => ret := d.bDescriptorType;
            when 2 => ret := d.bInterfaceNumber;
            when 3 => ret := d.bAlternateSetting;
            when 4 => ret := d.bNumEndpoints;
            when 5 => ret := d.bInterfaceClass;
            when 6 => ret := d.bInterfaceSubClass;
            when 7 => ret := d.bInterfaceProtocol;
            when 8 => ret := d.iInterface;
            when others => null;
        end case;
        return ret;
    end function;

    function serialize_usb_endpoint_descriptor(d: usb_endpoint_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.bLength;
            when 1 => ret := d.bDescriptorType;
            when 2 => ret := d.bEndpointAddress;
            when 3 => ret := d.bmAttributes;
            when 4 => ret := d.wMaxPacketSize( 7 downto 0);
            when 5 => ret := d.wMaxPacketSize(15 downto 8);
            when 6 => ret := d.bInterval;
            when others => null;
        end case;
        return ret;
    end function;
end package body;
