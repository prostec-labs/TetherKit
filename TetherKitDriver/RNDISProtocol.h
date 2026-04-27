/* RNDISProtocol.h
 * RNDIS protocol definitions for TetherKit (DriverKit port of HoRNDIS).
 * HoRNDIS — RNDIS USB tethering driver for macOS
 *
 *   Copyright (c) 2012 Joshua Wise.
 *   Copyright (c) 2018 Mikhail Iakhiaev
 *
 * RNDIS logic derived from linux/drivers/net/usb/rndis_host.c:
 *   Copyright (c) 2005 David Brownell.
 *
 * Ported to DriverKit by Prostec Labs, 2026.
 *
 * REFERENCES:
 * [MS-RNDIS]: Remote Network Driver Interface Specification (RNDIS) Protocol
 * [MSDN-RNDISUSB]: Remote NDIS To USB Mapping
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 */

#pragma once

#include <stdint.h>

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#  define cpu_to_le32(x)  ((uint32_t)(x))
#  define le32_to_cpu(x)  ((uint32_t)(x))
#else
#  define cpu_to_le32(x)  __builtin_bswap32((uint32_t)(x))
#  define le32_to_cpu(x)  __builtin_bswap32((uint32_t)(x))
#endif

static constexpr uint32_t OUT_BUF_SIZE  = 4096;
static constexpr uint32_t IN_BUF_SIZE   = 16384;
static constexpr int N_OUT_BUFS = 4;
static constexpr int N_IN_BUFS  = 1;
static constexpr uint32_t ETHERNET_MTU = 1500;
static constexpr uint32_t RNDIS_CMD_BUF_SZ = 1024;
static constexpr uint32_t PACKET_POOL_CAPACITY = 64;
static constexpr uint32_t PACKET_QUEUE_DEPTH = 16;

static constexpr uint8_t USB_CDC_SEND_ENCAPSULATED_COMMAND = 0x00;
static constexpr uint8_t USB_CDC_GET_ENCAPSULATED_RESPONSE = 0x01;

struct rndis_msg_hdr {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t status;
} __attribute__((packed));

struct rndis_data_hdr {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t data_offset;
    uint32_t data_len;
    uint32_t oob_data_offset;
    uint32_t oob_data_len;
    uint32_t num_oob;
    uint32_t packet_data_offset;
    uint32_t packet_data_len;
    uint32_t vc_handle;
    uint32_t reserved;
} __attribute__((packed));

struct rndis_query {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t oid;
    uint32_t len;
    uint32_t offset;
    uint32_t handle;
} __attribute__((packed));

struct rndis_query_c {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t status;
    uint32_t len;
    uint32_t offset;
} __attribute__((packed));

struct rndis_init {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t major_version;
    uint32_t minor_version;
    uint32_t max_transfer_size;
} __attribute__((packed));

struct rndis_init_c {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t status;
    uint32_t major_version;
    uint32_t minor_version;
    uint32_t device_flags;
    uint32_t medium;
    uint32_t max_packets_per_transfer;
    uint32_t max_transfer_size;
    uint32_t packet_alignment;
    uint32_t af_list_offset;
    uint32_t af_list_size;
} __attribute__((packed));

struct rndis_set {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t oid;
    uint32_t len;
    uint32_t offset;
    uint32_t handle;
} __attribute__((packed));

struct rndis_set_c {
    uint32_t msg_type;
    uint32_t msg_len;
    uint32_t request_id;
    uint32_t status;
} __attribute__((packed));

static constexpr uint32_t RNDIS_MSG_COMPLETION  = cpu_to_le32(0x80000000u);
static constexpr uint32_t RNDIS_MSG_PACKET      = cpu_to_le32(0x00000001u);
static constexpr uint32_t RNDIS_MSG_INIT        = cpu_to_le32(0x00000002u);
static constexpr uint32_t RNDIS_MSG_INIT_C      = cpu_to_le32(0x80000002u);
static constexpr uint32_t RNDIS_MSG_HALT        = cpu_to_le32(0x00000003u);
static constexpr uint32_t RNDIS_MSG_QUERY       = cpu_to_le32(0x00000004u);
static constexpr uint32_t RNDIS_MSG_QUERY_C     = cpu_to_le32(0x80000004u);
static constexpr uint32_t RNDIS_MSG_SET         = cpu_to_le32(0x00000005u);
static constexpr uint32_t RNDIS_MSG_SET_C       = cpu_to_le32(0x80000005u);
static constexpr uint32_t RNDIS_MSG_RESET       = cpu_to_le32(0x00000006u);
static constexpr uint32_t RNDIS_MSG_RESET_C     = cpu_to_le32(0x80000006u);
static constexpr uint32_t RNDIS_MSG_INDICATE    = cpu_to_le32(0x00000007u);
static constexpr uint32_t RNDIS_MSG_KEEPALIVE   = cpu_to_le32(0x00000008u);
static constexpr uint32_t RNDIS_MSG_KEEPALIVE_C = cpu_to_le32(0x80000008u);

static constexpr uint32_t RNDIS_STATUS_SUCCESS                   = cpu_to_le32(0x00000000u);
static constexpr uint32_t RNDIS_STATUS_FAILURE                   = cpu_to_le32(0xC0000001u);
static constexpr uint32_t RNDIS_STATUS_INVALID_DATA              = cpu_to_le32(0xC0010015u);
static constexpr uint32_t RNDIS_STATUS_NOT_SUPPORTED             = cpu_to_le32(0xC00000BBu);
static constexpr uint32_t RNDIS_STATUS_MEDIA_CONNECT             = cpu_to_le32(0x4001000Bu);
static constexpr uint32_t RNDIS_STATUS_MEDIA_DISCONNECT          = cpu_to_le32(0x4001000Cu);
static constexpr uint32_t RNDIS_STATUS_MEDIA_SPECIFIC_INDICATION = cpu_to_le32(0x40010012u);

static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_UNSPECIFIED   = cpu_to_le32(0x00000000u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_WIRELESS_LAN  = cpu_to_le32(0x00000001u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_CABLE_MODEM   = cpu_to_le32(0x00000002u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_PHONE_LINE    = cpu_to_le32(0x00000003u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_POWER_LINE    = cpu_to_le32(0x00000004u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_DSL           = cpu_to_le32(0x00000005u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_FIBRE_CHANNEL = cpu_to_le32(0x00000006u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_1394          = cpu_to_le32(0x00000007u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_WIRELESS_WAN  = cpu_to_le32(0x00000008u);
static constexpr uint32_t RNDIS_PHYSICAL_MEDIUM_MAX           = cpu_to_le32(0x00000009u);

static constexpr uint32_t OID_802_3_PERMANENT_ADDRESS   = cpu_to_le32(0x01010101u);
static constexpr uint32_t OID_802_3_CURRENT_ADDRESS     = cpu_to_le32(0x01010102u);
static constexpr uint32_t OID_GEN_MAXIMUM_FRAME_SIZE    = cpu_to_le32(0x00010106u);
static constexpr uint32_t OID_GEN_CURRENT_PACKET_FILTER = cpu_to_le32(0x0001010Eu);
static constexpr uint32_t OID_GEN_PHYSICAL_MEDIUM       = cpu_to_le32(0x00010202u);

static constexpr uint32_t RNDIS_PACKET_TYPE_DIRECTED       = cpu_to_le32(0x00000001u);
static constexpr uint32_t RNDIS_PACKET_TYPE_MULTICAST      = cpu_to_le32(0x00000002u);
static constexpr uint32_t RNDIS_PACKET_TYPE_ALL_MULTICAST  = cpu_to_le32(0x00000004u);
static constexpr uint32_t RNDIS_PACKET_TYPE_BROADCAST      = cpu_to_le32(0x00000008u);
static constexpr uint32_t RNDIS_PACKET_TYPE_SOURCE_ROUTING = cpu_to_le32(0x00000010u);
static constexpr uint32_t RNDIS_PACKET_TYPE_PROMISCUOUS    = cpu_to_le32(0x00000020u);
static constexpr uint32_t RNDIS_PACKET_TYPE_SMT            = cpu_to_le32(0x00000040u);
static constexpr uint32_t RNDIS_PACKET_TYPE_ALL_LOCAL      = cpu_to_le32(0x00000080u);
static constexpr uint32_t RNDIS_PACKET_TYPE_GROUP          = cpu_to_le32(0x00001000u);
static constexpr uint32_t RNDIS_PACKET_TYPE_ALL_FUNCTIONAL = cpu_to_le32(0x00002000u);
static constexpr uint32_t RNDIS_PACKET_TYPE_FUNCTIONAL     = cpu_to_le32(0x00004000u);
static constexpr uint32_t RNDIS_PACKET_TYPE_MAC_FRAME      = cpu_to_le32(0x00008000u);

static constexpr uint32_t RNDIS_DEFAULT_FILTER =
    RNDIS_PACKET_TYPE_DIRECTED |
    RNDIS_PACKET_TYPE_BROADCAST |
    RNDIS_PACKET_TYPE_ALL_MULTICAST |
    RNDIS_PACKET_TYPE_PROMISCUOUS;

static constexpr uint32_t RNDIS_DATA_HDR_DATA_OFFSET = cpu_to_le32(0x00000024u);
