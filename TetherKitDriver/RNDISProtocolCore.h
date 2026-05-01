/* RNDISProtocolCore.h
 * Pure C++ surface for the RNDIS framing math — no DriverKit deps.
 * Linkable from the dext target (full DriverKit context) AND from the
 * TetherKitProtocolTests host XCTest target.
 */

#pragma once

#include <stdint.h>
#include "RNDISProtocol.h"

namespace rndis {

enum class ParseResult : int {
    OK = 0,
    TRUNCATED_HEADER,
    WRONG_MSG_TYPE,
    INVALID_MSG_LEN,
    INVALID_DATA_BOUNDS,
};

/// Callback: receives one Ethernet payload per RNDIS PACKET_MSG with non-zero data_len.
typedef void (*PacketCallback)(void * context,
                               const uint8_t * data,
                               uint32_t        length);

/// Walks a bulk-IN buffer of zero or more concatenated REMOTE_NDIS_PACKET_MSG
/// frames. Calls cb for every packet that passes bounds checks. Returns OK if
/// the entire buffer parsed cleanly, or the first failing condition. cb is NOT
/// invoked for data_len == 0.
ParseResult parseInboundBuffer(const uint8_t * buf,
                               uint32_t        size,
                               PacketCallback  cb,
                               void *          context);

/// Returns the transfer size to actually use given device-reported max and local
/// buffer ceiling. Floor is (sizeof(rndis_data_hdr) + ETHERNET_MTU + 14).
uint32_t clampMaxTransferSize(uint32_t deviceReportedMax,
                              uint32_t outBufPayloadMax);

/// If the multicast bit (LSB of octet 0) is set, clears it and sets the
/// locally-administered bit. Returns true if a fixup was applied.
bool fixupMacMulticastBit(uint8_t mac[6]);

} // namespace rndis
