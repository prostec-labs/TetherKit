/* RNDISProtocolCore.cpp
 * Pure C++ implementation of the testable RNDIS framing math.
 */

#include "RNDISProtocolCore.h"

namespace rndis {

ParseResult parseInboundBuffer(const uint8_t * buf,
                               uint32_t        size,
                               PacketCallback  cb,
                               void *          context)
{
    while (size > 0) {
        if (size < sizeof(rndis_data_hdr)) {
            return ParseResult::TRUNCATED_HEADER;
        }
        const auto * hdr = reinterpret_cast<const rndis_data_hdr *>(buf);
        const uint32_t msgLen  = le32_to_cpu(hdr->msg_len);
        const uint32_t dataOfs = le32_to_cpu(hdr->data_offset);
        const uint32_t dataLen = le32_to_cpu(hdr->data_len);

        if (hdr->msg_type != RNDIS_MSG_PACKET) {
            return ParseResult::WRONG_MSG_TYPE;
        }
        if (msgLen > size || msgLen < sizeof(rndis_data_hdr)) {
            return ParseResult::INVALID_MSG_LEN;
        }
        if (dataOfs > msgLen ||
            dataLen > msgLen ||
            (8u + dataOfs + dataLen) > msgLen) {
            return ParseResult::INVALID_DATA_BOUNDS;
        }
        if (dataLen > 0 && cb) {
            cb(context, buf + 8u + dataOfs, dataLen);
        }
        size -= msgLen;
        buf  += msgLen;
    }
    return ParseResult::OK;
}

uint32_t clampMaxTransferSize(uint32_t deviceReportedMax, uint32_t outBufPayloadMax)
{
    uint32_t v = (deviceReportedMax < outBufPayloadMax) ? deviceReportedMax : outBufPayloadMax;
    const uint32_t floor =
        static_cast<uint32_t>(sizeof(rndis_data_hdr)) + ETHERNET_MTU + 14u;
    if (v < floor) {
        v = (floor < outBufPayloadMax) ? floor : outBufPayloadMax;
    }
    return v;
}

bool fixupMacMulticastBit(uint8_t mac[6])
{
    if ((mac[0] & 0x01u) == 0) {
        return false;
    }
    mac[0] = static_cast<uint8_t>((mac[0] & 0xFEu) | 0x02u);
    return true;
}

} // namespace rndis
