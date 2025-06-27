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
    -- Define reasonable maximums
    constant MAX_STRING_LENGTH:       positive := 32;
    constant MAX_STRING_COUNT:        positive := 32;
    constant MAX_CLASSES_LENGTH:      positive := 64; -- per interface
    constant MAX_ENDPOINT_COUNT:      positive :=  8; -- per interface
    constant MAX_INTERFACE_COUNT:     positive :=  8; -- per configuration
    constant MAX_CONFIGURATION_COUNT: positive :=  4;

    --------------------------------------------------

    -- Descriptor header
    type usb_descriptor_header_t is record
        rom_offset: unsigned(15 downto 0);

        bLength:         usb_byte_t;
        bDescriptorType: usb_byte_t;
    end record;

    constant EMPTY_USB_DESCRIPTOR_HEADER: usb_descriptor_header_t := (
        rom_offset => (others => '0'),

        bLength         => (others => '0'),
        bDescriptorType => (others => '0')
    );

    --------------------------------------------------

    -- String descriptor
    type usb_string_descriptor_t is record
        header:  usb_descriptor_header_t;
        bString: usb_word_array_t(0 to MAX_STRING_LENGTH - 1);
    end record;

    constant EMPTY_USB_STRING_DESCRIPTOR: usb_string_descriptor_t := (
        header  => EMPTY_USB_DESCRIPTOR_HEADER,
        bString => (others => (others => '0'))
    );

    type usb_string_descriptor_array_t is array(natural range <>) of usb_string_descriptor_t;

    function new_usb_string_zero(langs: usb_word_array_t) return usb_string_descriptor_t;
    function to_usb_string_descriptor(s: string) return usb_string_descriptor_t;
    function serialize(d: usb_string_descriptor_t; i: natural) return usb_byte_t;
    function get_string_count(d: usb_string_descriptor_array_t) return natural;
    function get_total_size(d: usb_string_descriptor_array_t) return natural;

    --------------------------------------------------

    -- Endpoint descriptor
    type usb_endpoint_descriptor_t is record
        header:           usb_descriptor_header_t;
        bEndpointAddress: usb_byte_t;
        bmAttributes:     usb_byte_t;
        wMaxPacketSize:   usb_word_t;
        bInterval:        usb_byte_t;
    end record;

    constant EMPTY_USB_ENDPOINT_DESCRIPTOR: usb_endpoint_descriptor_t := (
        header           => EMPTY_USB_DESCRIPTOR_HEADER,
        bEndpointAddress => (others => '0'),
        bmAttributes     => (others => '0'),
        wMaxPacketSize   => (others => '0'),
        bInterval        => (others => '0')
    );

    type usb_endpoint_descriptor_array_t is array(natural range <>) of usb_endpoint_descriptor_t;

    type usb_endpoint_direction_t is (ep_in, ep_out);
    type usb_endpoint_transfer_type_t is (control, isochronous, bulk, interrupt);
    type usb_endpoint_sync_type_t is (no_sync, async, adaptive_sync, sync);
    type usb_endpoint_usage_type_t is (data, feedback, explicit);
    function new_usb_endpoint(
        addr:            integer range 1 to 15;
        dir:             usb_endpoint_direction_t;
        transfer_type:   usb_endpoint_transfer_type_t;
        sync_type:       usb_endpoint_sync_type_t;
        usage_type:      usb_endpoint_usage_type_t;
        max_packet_size: integer range 1 to 65535;
        interval:        integer range 1 to 255
    ) return usb_endpoint_descriptor_t;

    function serialize(d: usb_endpoint_descriptor_t; i: natural) return usb_byte_t;

    --------------------------------------------------

    -- Interface descriptor
    type usb_interface_descriptor_t is record
        header:             usb_descriptor_header_t;
        bInterfaceNumber:   usb_byte_t;
        bAlternateSetting:  usb_byte_t;
        bNumEndpoints:      usb_byte_t;
        bInterfaceClass:    usb_byte_t;
        bInterfaceSubClass: usb_byte_t;
        bInterfaceProtocol: usb_byte_t;
        iInterface:         usb_byte_t;

        classes_length: natural;
        classes:        usb_byte_array_t(0 to MAX_CLASSES_LENGTH - 1);
        endpoints:      usb_endpoint_descriptor_array_t(0 to MAX_ENDPOINT_COUNT - 1);
    end record;

    constant EMPTY_USB_INTERFACE_DESCRIPTOR: usb_interface_descriptor_t := (
        header             => EMPTY_USB_DESCRIPTOR_HEADER,
        bInterfaceNumber   => (others => '0'),
        bAlternateSetting  => (others => '0'),
        bNumEndpoints      => (others => '0'),
        bInterfaceClass    => (others => '0'),
        bInterfaceSubClass => (others => '0'),
        bInterfaceProtocol => (others => '0'),
        iInterface         => (others => '0'),

        classes_length => 0,
        classes        => (others => (others => '0')),
        endpoints      => (others => EMPTY_USB_ENDPOINT_DESCRIPTOR)
    );

    type usb_interface_descriptor_array_t is array(natural range <>) of usb_interface_descriptor_t;

    function new_usb_interface(
        number:      integer range 0 to 255;
        alt_setting: integer range 0 to 255;
        class:       integer range 0 to 255;
        sub_class:   integer range 0 to 255;
        protocol:    integer range 0 to 255;
        desc_string: integer range 0 to 255;
        classes:     usb_byte_array_t;
        endpoints:   usb_endpoint_descriptor_array_t
    ) return usb_interface_descriptor_t;

    function serialize(d: usb_interface_descriptor_t; i: natural) return usb_byte_t;

    --------------------------------------------------

    -- Configuration descriptor
    type usb_configuration_descriptor_t is record
        header:              usb_descriptor_header_t;
        wTotalLength:        usb_word_t;
        bNumInterfaces:      usb_byte_t;
        bConfigurationValue: usb_byte_t;
        iConfiguration:      usb_byte_t;
        bmAttributes:        usb_byte_t;
        bMaxPower:           usb_byte_t;

        interfaces: usb_interface_descriptor_array_t(0 to MAX_INTERFACE_COUNT - 1);
    end record;

    constant EMPTY_USB_CONFIGURATION_DESCRIPTOR: usb_configuration_descriptor_t := (
        header              => EMPTY_USB_DESCRIPTOR_HEADER,
        wTotalLength        => (others => '0'),
        bNumInterfaces      => (others => '0'),
        bConfigurationValue => (others => '0'),
        iConfiguration      => (others => '0'),
        bmAttributes        => (others => '0'),
        bMaxPower           => (others => '0'),

        interfaces => (others => EMPTY_USB_INTERFACE_DESCRIPTOR)
    );

    type usb_configuration_descriptor_array_t is array(natural range <>) of usb_configuration_descriptor_t;

    function new_usb_configuration(
        desc_string:   integer range 0 to 255;
        self_powered:  boolean;
        remote_wakeup: boolean;
        max_power:     integer range 0 to 500;
        interfaces:    usb_interface_descriptor_array_t
    ) return usb_configuration_descriptor_t;

    function serialize(d: usb_configuration_descriptor_t; i: natural) return usb_byte_t;

    --------------------------------------------------

    -- Device descriptor
    type usb_device_descriptor_t is record
        header:             usb_descriptor_header_t;
        bcdUSB:             usb_word_t;
        bDeviceClass:       usb_byte_t;
        bDeviceSubClass:    usb_byte_t;
        bDeviceProtocol:    usb_byte_t;
        bMaxPacketSize0:    usb_byte_t;
        idVendor:           usb_word_t;
        idProduct:          usb_word_t;
        bcdDevice:          usb_word_t;
        iManufacturer:      usb_byte_t;
        iProduct:           usb_byte_t;
        iSerialNumber:      usb_byte_t;
        bNumConfigurations: usb_byte_t;

        configurations: usb_configuration_descriptor_array_t(0 to MAX_CONFIGURATION_COUNT - 1);
    end record;

    constant EMPTY_USB_DEVICE_DESCRIPTOR: usb_device_descriptor_t := (
        header             => EMPTY_USB_DESCRIPTOR_HEADER,
        bcdUSB             => (others => '0'),
        bDeviceClass       => (others => '0'),
        bDeviceSubClass    => (others => '0'),
        bDeviceProtocol    => (others => '0'),
        bMaxPacketSize0    => (others => '0'),
        idVendor           => (others => '0'),
        idProduct          => (others => '0'),
        bcdDevice          => (others => '0'),
        iManufacturer      => (others => '0'),
        iProduct           => (others => '0'),
        iSerialNumber      => (others => '0'),
        bNumConfigurations => (others => '0'),

        configurations => (others => EMPTY_USB_CONFIGURATION_DESCRIPTOR)
    );

    function new_usb_device(
        class:               integer range 0 to 255;
        sub_class:           integer range 0 to 255;
        protocol:            integer range 0 to 255;
        max_packet_size_0:   integer range 8 to 64;
        vendor_id:           integer range 0 to 65535;
        product_id:          integer range 0 to 65535;
        bcd_device:          integer range 0 to 65535;
        manufacturer_string: integer range 0 to 255;
        product_string:      integer range 0 to 255;
        serial_string:       integer range 0 to 255;
        configurations:      usb_configuration_descriptor_array_t
    ) return usb_device_descriptor_t;

    function serialize(d: usb_device_descriptor_t; i: natural) return usb_byte_t;
    function get_total_size(d: usb_device_descriptor_t) return natural;

    --------------------------------------------------

    -- Combined descriptors
    type usb_descriptors_t is record
        device:  usb_device_descriptor_t;
        strings: usb_string_descriptor_array_t(0 to MAX_STRING_COUNT - 1);
    end record;

    constant EMPTY_USB_DESCRIPTORS: usb_descriptors_t := (
        device  => EMPTY_USB_DEVICE_DESCRIPTOR,
        strings => (others => EMPTY_USB_STRING_DESCRIPTOR)
    );

    function new_usb_descriptors(
        device:  usb_device_descriptor_t;
        strings: usb_string_descriptor_array_t
    ) return usb_descriptors_t;

    function to_byte_array(d: usb_descriptors_t) return usb_byte_array_t;
end package;

--------------------------------------------------

package body usb_descriptors is
    -- Create a new string descriptor containing the supported languages
    function new_usb_string_zero(langs: usb_word_array_t) return usb_string_descriptor_t is
        variable ret: usb_string_descriptor_t := EMPTY_USB_STRING_DESCRIPTOR;
    begin
        ret.header.bLength         := usb_byte_t(to_unsigned(langs'length * 2 + 2, ret.header.bLength'length));
        ret.header.bDescriptorType := x"03";

        -- TODO: handle multiple languages
        assert langs'length = 1 report "Multiple languages are not supported yet" severity error;

        -- Copy the languages array
        for i in langs'low to langs'high loop
            ret.bString(i - langs'low) := langs(i);
        end loop;

        return ret;
    end function;

    -- Convert a VHDL string into a USB string descriptor
    function to_usb_string_descriptor(s: string) return usb_string_descriptor_t is
        variable ret: usb_string_descriptor_t := EMPTY_USB_STRING_DESCRIPTOR;
    begin
        ret.header.bLength         := usb_byte_t(to_unsigned(s'length * 2 + 2, ret.header.bLength'length));
        ret.header.bDescriptorType := x"03";

        -- Convert the ASCII string into UTF-16 character by character
        if s'length > 0 then
            for i in s'low to s'high loop
                ret.bString(i - s'low)( 7 downto 0) := usb_byte_t(to_unsigned(character'pos(s(i)), 8));
                ret.bString(i - s'low)(15 downto 8) := (others => '0');
            end loop;
        end if;

        return ret;
    end function;

    -- Get the byte at the specified offset of the string descriptor
    function serialize(d: usb_string_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.header.bLength;
            when 1 => ret := d.header.bDescriptorType;
            when 2 to d.bString'length - 3 =>
                if i mod 2 = 0 then
                    ret := d.bString((i - 2) / 2)( 7 downto 0);
                else
                    ret := d.bString((i - 2) / 2)(15 downto 8);
                end if;
            when others => null;
        end case;
        return ret;
    end function;

    -- Get the amount of defined strings in an array
    function get_string_count(d: usb_string_descriptor_array_t) return natural is
        variable ret: natural := 0;
    begin
        for i in d'range loop
            if unsigned(d(i).header.bLength) /= 0 then
                ret := ret + 1;
            end if;
        end loop;
        return ret;
    end function;

    -- Get the size necessary to serialize a string array
    function get_total_size(d: usb_string_descriptor_array_t) return natural is
        variable total_size: natural := 0;
    begin
        for i in d'range loop
            total_size := total_size + to_integer(unsigned(d(i).header.bLength));
        end loop;
        return total_size;
    end function;

    --------------------------------------------------

    -- Create a new USB endpoint
    function new_usb_endpoint(
        addr:            integer range 1 to 15;
        dir:             usb_endpoint_direction_t;
        transfer_type:   usb_endpoint_transfer_type_t;
        sync_type:       usb_endpoint_sync_type_t;
        usage_type:      usb_endpoint_usage_type_t;
        max_packet_size: integer range 1 to 65535;
        interval:        integer range 1 to 255
    ) return usb_endpoint_descriptor_t is
        variable ret: usb_endpoint_descriptor_t := EMPTY_USB_ENDPOINT_DESCRIPTOR;
    begin
        ret.header.bLength         := x"07";
        ret.header.bDescriptorType := x"05";

        ret.bEndpointAddress := usb_byte_t(to_unsigned(addr, ret.bEndpointAddress'length));
        case dir is
            when ep_in  => ret.bEndpointAddress(7) := '1';
            when ep_out => ret.bEndpointAddress(7) := '0';
        end case;
        ret.bmAttributes     := (others => '0');
        case transfer_type is
            when control     => ret.bmAttributes(1 downto 0) := "00";
            when isochronous => ret.bmAttributes(1 downto 0) := "01";
            when bulk        => ret.bmAttributes(1 downto 0) := "10";
            when interrupt   => ret.bmAttributes(1 downto 0) := "11";
        end case;
        case sync_type is
            when no_sync       => ret.bmAttributes(3 downto 2) := "00";
            when async         => ret.bmAttributes(3 downto 2) := "01";
            when adaptive_sync => ret.bmAttributes(3 downto 2) := "10";
            when sync          => ret.bmAttributes(3 downto 2) := "11";
        end case;
        case usage_type is
            when data     => ret.bmAttributes(5 downto 4) := "00";
            when feedback => ret.bmAttributes(5 downto 4) := "01";
            when explicit => ret.bmAttributes(5 downto 4) := "10";
        end case;
        ret.wMaxPacketSize := usb_word_t(to_unsigned(max_packet_size, ret.wMaxPacketSize'length));
        ret.bInterval      := usb_byte_t(to_unsigned(interval,        ret.bInterval'length));

        return ret;
    end function;

    -- Get the byte at the specified offset of the endpoint descriptor
    function serialize(d: usb_endpoint_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.header.bLength;
            when 1 => ret := d.header.bDescriptorType;
            when 2 => ret := d.bEndpointAddress;
            when 3 => ret := d.bmAttributes;
            when 4 => ret := d.wMaxPacketSize( 7 downto 0);
            when 5 => ret := d.wMaxPacketSize(15 downto 8);
            when 6 => ret := d.bInterval;
            when others => null;
        end case;
        return ret;
    end function;

    --------------------------------------------------

    -- Create a new USB interface
    function new_usb_interface(
        number:      integer range 0 to 255;
        alt_setting: integer range 0 to 255;
        class:       integer range 0 to 255;
        sub_class:   integer range 0 to 255;
        protocol:    integer range 0 to 255;
        desc_string: integer range 0 to 255;
        classes:     usb_byte_array_t;
        endpoints:   usb_endpoint_descriptor_array_t
    ) return usb_interface_descriptor_t is
        variable ret: usb_interface_descriptor_t := EMPTY_USB_INTERFACE_DESCRIPTOR;
    begin
        ret.header.bLength         := x"09";
        ret.header.bDescriptorType := x"04";

        ret.bInterfaceNumber   := usb_byte_t(to_unsigned(number,           ret.bInterfaceNumber'length));
        ret.bAlternateSetting  := usb_byte_t(to_unsigned(alt_setting,      ret.bAlternateSetting'length));
        ret.bNumEndpoints      := usb_byte_t(to_unsigned(endpoints'length, ret.bNumEndpoints'length));
        ret.bInterfaceClass    := usb_byte_t(to_unsigned(class,            ret.bInterfaceClass'length));
        ret.bInterfaceSubClass := usb_byte_t(to_unsigned(sub_class,        ret.bInterfaceSubClass'length));
        ret.bInterfaceProtocol := usb_byte_t(to_unsigned(protocol,         ret.bInterfaceProtocol'length));
        ret.iInterface         := usb_byte_t(to_unsigned(desc_string,      ret.iInterface'length));

        -- Copy the classes, if any
        if classes'length > 0 then
            ret.classes_length := classes'length;
            for i in classes'low to classes'high loop
                ret.classes(i - classes'low) := classes(i);
            end loop;
        end if;

        -- Copy the endpoints
        for i in endpoints'low to endpoints'high loop
            ret.endpoints(i - endpoints'low) := endpoints(i);
        end loop;

        return ret;
    end function;

    -- Get the byte at the specified offset of the interface descriptor
    function serialize(d: usb_interface_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.header.bLength;
            when 1 => ret := d.header.bDescriptorType;
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

    --------------------------------------------------

    -- Create a new USB configuration
    function new_usb_configuration(
        desc_string:   integer range 0 to 255;
        self_powered:  boolean;
        remote_wakeup: boolean;
        max_power:     integer range 0 to 500;
        interfaces:    usb_interface_descriptor_array_t
    ) return usb_configuration_descriptor_t is
        variable ret: usb_configuration_descriptor_t := EMPTY_USB_CONFIGURATION_DESCRIPTOR;
        variable wTotalLength: integer range 0 to 65535;
    begin
        ret.header.bLength         := x"09";
        ret.header.bDescriptorType := x"02";

        ret.bNumInterfaces      := usb_byte_t(to_unsigned(interfaces'length, ret.bNumInterfaces'length));
        ret.iConfiguration      := usb_byte_t(to_unsigned(desc_string,       ret.iConfiguration'length));
        ret.bmAttributes        := (7 => '1', others => '0');
        if self_powered then
            ret.bmAttributes(6) := '1';
        end if;
        if remote_wakeup then
            ret.bmAttributes(5) := '1';
        end if;
        ret.bMaxPower           := usb_byte_t(to_unsigned(max_power, ret.bMaxPower'length) / 2);

        -- Copy the interfaces
        for i in interfaces'low to interfaces'high loop
            ret.interfaces(i - interfaces'low) := interfaces(i);
        end loop;

        -- Compute the configuration size
        wTotalLength := to_integer(unsigned(ret.header.bLength));
        for i in ret.interfaces'range loop
            wTotalLength := wTotalLength + to_integer(unsigned(ret.interfaces(i).header.bLength));
            wTotalLength := wTotalLength + ret.interfaces(i).classes_length;
            for j in ret.interfaces(i).endpoints'range loop
                wTotalLength := wTotalLength + to_integer(unsigned(ret.interfaces(i).endpoints(j).header.bLength));
            end loop;
        end loop;
        ret.wTotalLength := usb_word_t(to_unsigned(wTotalLength, ret.wTotalLength'length));

        return ret;
    end function;

    -- Get the byte at the specified offset of the configuration descriptor
    function serialize(d: usb_configuration_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when 0 => ret := d.header.bLength;
            when 1 => ret := d.header.bDescriptorType;
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

    --------------------------------------------------

    -- Create a new USB device
    function new_usb_device(
        class:               integer range 0 to 255;
        sub_class:           integer range 0 to 255;
        protocol:            integer range 0 to 255;
        max_packet_size_0:   integer range 8 to 64;
        vendor_id:           integer range 0 to 65535;
        product_id:          integer range 0 to 65535;
        bcd_device:          integer range 0 to 65535;
        manufacturer_string: integer range 0 to 255;
        product_string:      integer range 0 to 255;
        serial_string:       integer range 0 to 255;
        configurations:      usb_configuration_descriptor_array_t
    ) return usb_device_descriptor_t is
        variable ret: usb_device_descriptor_t := EMPTY_USB_DEVICE_DESCRIPTOR;
    begin
        case max_packet_size_0 is
            when 8 | 16 | 32 | 64 => null;
            when others => report "bMaxPacketSize0 must be 8, 16, 32, or 64" severity error;
        end case;

        ret.header.bLength         := x"12";
        ret.header.bDescriptorType := x"01";

        ret.bcdUSB             := x"0110"; -- USB 1.1
        ret.bDeviceClass       := usb_byte_t(to_unsigned(class,                 ret.bDeviceClass'length));
        ret.bDeviceSubClass    := usb_byte_t(to_unsigned(sub_class,             ret.bDeviceSubClass'length));
        ret.bDeviceProtocol    := usb_byte_t(to_unsigned(protocol,              ret.bDeviceProtocol'length));
        ret.bMaxPacketSize0    := usb_byte_t(to_unsigned(max_packet_size_0,     ret.bMaxPacketSize0'length));
        ret.idVendor           := usb_word_t(to_unsigned(vendor_id,             ret.idVendor'length));
        ret.idProduct          := usb_word_t(to_unsigned(product_id,            ret.idProduct'length));
        ret.bcdDevice          := usb_word_t(to_unsigned(bcd_device,            ret.bcdDevice'length));
        ret.iManufacturer      := usb_byte_t(to_unsigned(manufacturer_string,   ret.iManufacturer'length));
        ret.iProduct           := usb_byte_t(to_unsigned(product_string,        ret.iProduct'length));
        ret.iSerialNumber      := usb_byte_t(to_unsigned(serial_string,         ret.iSerialNumber'length));
        ret.bNumConfigurations := usb_byte_t(to_unsigned(configurations'length, ret.bNumConfigurations'length));

        -- Copy the configurations and assign configuration IDs
        for i in configurations'low to configurations'high loop
            ret.configurations(i - configurations'low)                     := configurations(i);
            ret.configurations(i - configurations'low).bConfigurationValue := usb_byte_t(to_unsigned(i - configurations'low + 1, 8));
        end loop;

        return ret;
    end function;

    -- Get the byte at the specified offset of the device descriptor
    function serialize(d: usb_device_descriptor_t; i: natural) return usb_byte_t is
        variable ret: usb_byte_t := (others => '0');
    begin
        case i is
            when  0 => ret := d.header.bLength;
            when  1 => ret := d.header.bDescriptorType;
            when  2 => ret := d.bcdUSB( 7 downto 0);
            when  3 => ret := d.bcdUSB(15 downto 8);
            when  4 => ret := d.bDeviceClass;
            when  5 => ret := d.bDeviceSubClass;
            when  6 => ret := d.bDeviceProtocol;
            when  7 => ret := d.bMaxPacketSize0;
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

    -- Get the size necessary to serialize the descriptors
    function get_total_size(d: usb_device_descriptor_t) return natural is
        variable total_size: natural := 0;
    begin
        total_size := to_integer(unsigned(d.header.bLength));
        for i in d.configurations'range loop
            total_size := total_size + to_integer(unsigned(d.configurations(i).wTotalLength));
        end loop;
        return total_size;
    end function;

    --------------------------------------------------

    function new_usb_descriptors(
        device:  usb_device_descriptor_t;
        strings: usb_string_descriptor_array_t
    ) return usb_descriptors_t is
        variable ret: usb_descriptors_t := EMPTY_USB_DESCRIPTORS;
        variable rom_offset: unsigned(ret.device.header.rom_offset'range) := (others => '0');
    begin
        -- Copy the device
        ret.device := device;

        -- Copy the strings
        for i in strings'low to strings'high loop
            ret.strings(i - strings'low) := strings(i);
        end loop;

        -- Update the device ROM offset
        ret.device.header.rom_offset := (others => '0');
        rom_offset := rom_offset + unsigned(ret.device.header.bLength);

        -- Update the configurations ROM offsets
        for conf_index in 0 to to_integer(unsigned(ret.device.bNumConfigurations)) - 1 loop
            ret.device.configurations(conf_index).header.rom_offset := rom_offset;
            rom_offset := rom_offset + unsigned(ret.device.configurations(conf_index).header.bLength);

            -- Update the interfaces ROM offsets
            for iface_index in 0 to to_integer(unsigned(ret.device.configurations(conf_index).bNumInterfaces)) - 1 loop
                ret.device.configurations(conf_index).interfaces(iface_index).header.rom_offset := rom_offset;
                rom_offset := rom_offset + unsigned(ret.device.configurations(conf_index).interfaces(iface_index).header.bLength);
                rom_offset := rom_offset + to_unsigned(ret.device.configurations(conf_index).interfaces(iface_index).classes_length, rom_offset'length);

                -- Update the endpoints ROM offsets
                for endpoint_index in 0 to to_integer(unsigned(ret.device.configurations(conf_index).interfaces(iface_index).bNumEndpoints)) - 1 loop
                    ret.device.configurations(conf_index).interfaces(iface_index).endpoints(endpoint_index).header.rom_offset := rom_offset;
                    rom_offset := rom_offset + unsigned(ret.device.configurations(conf_index).interfaces(iface_index).endpoints(endpoint_index).header.bLength);
                end loop;
            end loop;
        end loop;

        -- Update the strings ROM offsets
        for i in ret.strings'low to ret.strings'high loop
            if unsigned(ret.strings(i).header.bLength) > 0 then
                ret.strings(i).header.rom_offset := rom_offset;
                rom_offset := rom_offset + unsigned(ret.strings(i).header.bLength);
            end if;
        end loop;

        return ret;
    end function;

    -- Convert the combined USB descriptors into a byte array
    function to_byte_array(d: usb_descriptors_t) return usb_byte_array_t is
        variable ret: usb_byte_array_t(0 to get_total_size(d.device) + get_total_size(d.strings) - 1) := (others => (others => '0'));
        variable out_index: natural := 0;
    begin
        -- Serialize the device descriptor
        for i in 0 to to_integer(unsigned(d.device.header.bLength)) - 1 loop
            ret(out_index) := serialize(d.device, i);
            out_index      := out_index + 1;
        end loop;

        -- Serialize configuration descriptors
        for conf_index in 0 to to_integer(unsigned(d.device.bNumConfigurations)) - 1 loop
            for i in 0 to to_integer(unsigned(d.device.configurations(conf_index).header.bLength)) - 1 loop
                ret(out_index) := serialize(d.device.configurations(conf_index), i);
                out_index      := out_index + 1;
            end loop;

            -- Serialize interface descriptors
            for iface_index in 0 to to_integer(unsigned(d.device.configurations(conf_index).bNumInterfaces)) - 1 loop
                for i in 0 to to_integer(unsigned(d.device.configurations(conf_index).interfaces(iface_index).header.bLength)) - 1 loop
                    ret(out_index) := serialize(d.device.configurations(conf_index).interfaces(iface_index), i);
                    out_index      := out_index + 1;
                end loop;

                -- Serialize class descriptors
                if d.device.configurations(conf_index).interfaces(iface_index).classes_length > 0 then
                    for i in 0 to d.device.configurations(conf_index).interfaces(iface_index).classes_length - 1 loop
                        ret(out_index) := d.device.configurations(conf_index).interfaces(iface_index).classes(i);
                        out_index      := out_index + 1;
                    end loop;
                end if;

                -- Serialize endpoint descriptors
                for endpoint_index in 0 to to_integer(unsigned(d.device.configurations(conf_index).interfaces(iface_index).bNumEndpoints)) - 1 loop
                    for i in 0 to to_integer(unsigned(d.device.configurations(conf_index).interfaces(iface_index).endpoints(endpoint_index).header.bLength)) - 1 loop
                        ret(out_index) := serialize(d.device.configurations(conf_index).interfaces(iface_index).endpoints(endpoint_index), i);
                        out_index      := out_index + 1;
                    end loop;
                end loop;
            end loop;
        end loop;

        -- Serialize the strings
        for i in d.strings'low to d.strings'high loop
            if unsigned(d.strings(i).header.bLength) > 0 then
                for j in 0 to to_integer(unsigned(d.strings(i).header.bLength)) - 1 loop
                    ret(out_index) := serialize(d.strings(i), j);
                    out_index      := out_index + 1;
                end loop;
            end if;
        end loop;

        return ret;
    end function;
end package body;
