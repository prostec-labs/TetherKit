// TetherKitProtocolTests.mm
// Pure-C++ unit tests for the RNDIS framing core. Links no DriverKit symbols.
//
// Build with: xcodebuild test -scheme TetherKitDriver \
//   -only-testing:TetherKitProtocolTests

#import <XCTest/XCTest.h>

#include "RNDISProtocol.h"
#include "RNDISProtocolCore.h"

#include <vector>
#include <cstring>

@interface TetherKitProtocolTests : XCTestCase
@end

@implementation TetherKitProtocolTests

// ---------------------------------------------------------------------------
// 1. Wire-format struct sizes
// ---------------------------------------------------------------------------

- (void)testRndisStructSizesMatchWireFormat {
    XCTAssertEqual(sizeof(rndis_msg_hdr),  16u, @"rndis_msg_hdr is 4 LE32s");
    XCTAssertEqual(sizeof(rndis_data_hdr), 44u, @"rndis_data_hdr is 11 LE32s");
    XCTAssertEqual(sizeof(rndis_query),    28u, @"rndis_query has 7 LE32s");
    XCTAssertEqual(sizeof(rndis_query_c),  24u, @"rndis_query_c has 6 LE32s");
    XCTAssertEqual(sizeof(rndis_init),     24u, @"rndis_init has 6 LE32s");
    XCTAssertEqual(sizeof(rndis_init_c),   52u, @"rndis_init_c has 13 LE32s");
    XCTAssertEqual(sizeof(rndis_set),      28u, @"rndis_set has 7 LE32s");
    XCTAssertEqual(sizeof(rndis_set_c),    16u, @"rndis_set_c has 4 LE32s");
}

// ---------------------------------------------------------------------------
// 2. parseInboundBuffer framing
// ---------------------------------------------------------------------------

namespace {
struct CapturedPacket { std::vector<uint8_t> bytes; };

static void capture(void * ctx, const uint8_t * data, uint32_t len) {
    auto * out = static_cast<std::vector<CapturedPacket> *>(ctx);
    CapturedPacket p;
    p.bytes.assign(data, data + len);
    out->push_back(std::move(p));
}

static std::vector<uint8_t> makePacketMessage(const uint8_t * eth, uint32_t ethLen) {
    const uint32_t totalLen = static_cast<uint32_t>(sizeof(rndis_data_hdr)) + ethLen;
    std::vector<uint8_t> buf(totalLen, 0);
    auto * hdr = reinterpret_cast<rndis_data_hdr *>(buf.data());
    hdr->msg_type    = RNDIS_MSG_PACKET;
    hdr->msg_len     = cpu_to_le32(totalLen);
    hdr->data_offset = RNDIS_DATA_HDR_DATA_OFFSET;
    hdr->data_len    = cpu_to_le32(ethLen);
    if (ethLen > 0 && eth) {
        std::memcpy(buf.data() + sizeof(rndis_data_hdr), eth, ethLen);
    }
    return buf;
}
} // namespace

- (void)testParseInboundBuffer_singleValidPacket {
    const uint8_t eth[] = { 0x10, 0x20, 0x30, 0x40, 0x50, 0x60 };
    auto buf = makePacketMessage(eth, sizeof(eth));
    std::vector<CapturedPacket> got;
    rndis::ParseResult r = rndis::parseInboundBuffer(buf.data(), (uint32_t)buf.size(), capture, &got);
    XCTAssertEqual(r, rndis::ParseResult::OK);
    XCTAssertEqual(got.size(), 1u);
    XCTAssertEqual(got[0].bytes.size(), sizeof(eth));
    XCTAssertEqual(std::memcmp(got[0].bytes.data(), eth, sizeof(eth)), 0);
}

- (void)testParseInboundBuffer_zeroLengthDataIsSkipped {
    auto buf = makePacketMessage(nullptr, 0);
    std::vector<CapturedPacket> got;
    rndis::ParseResult r = rndis::parseInboundBuffer(buf.data(), (uint32_t)buf.size(), capture, &got);
    XCTAssertEqual(r, rndis::ParseResult::OK);
    XCTAssertEqual(got.size(), 0u, @"data_len=0 must produce zero callbacks");
}

- (void)testParseInboundBuffer_multiPacketCoalescing {
    const uint8_t a[] = { 0xAA, 0xBB };
    const uint8_t b[] = { 0xCC, 0xDD, 0xEE };
    auto bufA = makePacketMessage(a, sizeof(a));
    auto bufB = makePacketMessage(b, sizeof(b));
    std::vector<uint8_t> joined;
    joined.insert(joined.end(), bufA.begin(), bufA.end());
    joined.insert(joined.end(), bufB.begin(), bufB.end());
    std::vector<CapturedPacket> got;
    rndis::ParseResult r = rndis::parseInboundBuffer(joined.data(), (uint32_t)joined.size(), capture, &got);
    XCTAssertEqual(r, rndis::ParseResult::OK);
    XCTAssertEqual(got.size(), 2u);
    XCTAssertEqual(got[0].bytes.size(), sizeof(a));
    XCTAssertEqual(got[1].bytes.size(), sizeof(b));
    XCTAssertEqual(std::memcmp(got[0].bytes.data(), a, sizeof(a)), 0);
    XCTAssertEqual(std::memcmp(got[1].bytes.data(), b, sizeof(b)), 0);
}

- (void)testParseInboundBuffer_oversizedDataLenRejected {
    auto buf = makePacketMessage(nullptr, 0);
    auto * hdr = reinterpret_cast<rndis_data_hdr *>(buf.data());
    hdr->data_len = cpu_to_le32(9999);
    std::vector<CapturedPacket> got;
    rndis::ParseResult r = rndis::parseInboundBuffer(buf.data(), (uint32_t)buf.size(), capture, &got);
    XCTAssertEqual(r, rndis::ParseResult::INVALID_DATA_BOUNDS);
    XCTAssertEqual(got.size(), 0u);
}

- (void)testParseInboundBuffer_truncatedHeaderRejected {
    uint8_t tiny[7] = {};
    std::vector<CapturedPacket> got;
    rndis::ParseResult r = rndis::parseInboundBuffer(tiny, sizeof(tiny), capture, &got);
    XCTAssertEqual(r, rndis::ParseResult::TRUNCATED_HEADER);
}

- (void)testParseInboundBuffer_wrongMsgTypeRejected {
    auto buf = makePacketMessage(nullptr, 0);
    auto * hdr = reinterpret_cast<rndis_data_hdr *>(buf.data());
    hdr->msg_type = RNDIS_MSG_INIT;
    std::vector<CapturedPacket> got;
    rndis::ParseResult r = rndis::parseInboundBuffer(buf.data(), (uint32_t)buf.size(), capture, &got);
    XCTAssertEqual(r, rndis::ParseResult::WRONG_MSG_TYPE);
}

// ---------------------------------------------------------------------------
// 3. clampMaxTransferSize
// ---------------------------------------------------------------------------

- (void)testClampMaxTransferSize_undersizedReportRaisedToFloor {
    const uint32_t floor = (uint32_t)sizeof(rndis_data_hdr) + ETHERNET_MTU + 14u;
    XCTAssertEqual(rndis::clampMaxTransferSize(100u, OUT_BUF_PAYLOAD_MAX), floor);
}

- (void)testClampMaxTransferSize_largeReportClampedToOutBuf {
    XCTAssertEqual(rndis::clampMaxTransferSize(0xFFFFFFFFu, OUT_BUF_PAYLOAD_MAX), OUT_BUF_PAYLOAD_MAX);
}

- (void)testClampMaxTransferSize_inRangeReportPassesThrough {
    XCTAssertEqual(rndis::clampMaxTransferSize(2048u, OUT_BUF_PAYLOAD_MAX), 2048u);
}

- (void)testClampMaxTransferSize_floorWhenOutBufBelowFloor {
    XCTAssertEqual(rndis::clampMaxTransferSize(100u, 256u), 256u);
}

// ---------------------------------------------------------------------------
// 4. fixupMacMulticastBit
// ---------------------------------------------------------------------------

- (void)testFixupMac_clearsMulticastSetsLocallyAdministered {
    uint8_t mac[6] = { 0x01, 0x22, 0x33, 0x44, 0x55, 0x66 };
    XCTAssertTrue(rndis::fixupMacMulticastBit(mac));
    XCTAssertEqual(mac[0] & 0x01u, 0u);
    XCTAssertEqual(mac[0] & 0x02u, 0x02u);
    XCTAssertEqual(mac[1], 0x22u);
    XCTAssertEqual(mac[5], 0x66u);
    XCTAssertEqual(mac[0], 0x02u);
}

- (void)testFixupMac_noChangeForUnicast {
    uint8_t mac[6] = { 0x02, 0x22, 0x33, 0x44, 0x55, 0x66 };
    uint8_t before[6];
    std::memcpy(before, mac, 6);
    XCTAssertFalse(rndis::fixupMacMulticastBit(mac));
    XCTAssertEqual(std::memcmp(mac, before, 6), 0);
}

@end
