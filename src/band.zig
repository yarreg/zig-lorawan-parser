const std = @import("std");

const table_eirp = [_]u8{ 8, 10, 12, 13, 14, 16, 18, 20, 21, 24, 26, 27, 29, 30, 33, 36 };

const Direction = enum(u8) {
    uplink,
    downlink,
    both,
};

const LoRaCodingrate = enum(u8) {
    cr4_5 = 45,
    cr4_6 = 46,
    cr4_7 = 47,
    cr4_8 = 48,
};

const LoRaBandwidth = enum(u16) {
    bw125 = 125,
    bw250 = 250,
    bw500 = 500,
};

const LoRaSpreadingFactor = enum(u8) {
    sf7 = 7,
    sf8 = 8,
    sf9 = 9,
    sf10 = 10,
    sf11 = 11,
    sf12 = 12,
};

const LoRaDatarate = struct {
    spreading_factor: LoRaSpreadingFactor,
    bandwidth: LoRaBandwidth,
    direction: Direction,
};

const FSKDataRate = struct {
    bitrate: u32,
    direction: Direction,
};

const LRFHSSCodingRate = enum(u8) {
    cr1_3 = 13,
    cr2_3 = 23,
};

const LRFHSSDataRate = struct {
    coding_rate: LRFHSSCodingRate,
    occupied_channel_width: u32,
    direction: Direction,
};

const Datarate = union(enum) {
    lora: LoRaDatarate,
    fsk: FSKDataRate,
    lrfhss: LRFHSSDataRate,
};

const MaxPayloadSize = union(enum) {
    dwell: struct {
        macpayload_dwell_0: u8,
        macpayload_dwell_1: u8,
    },
    macpayload: u8,
};

const Channel = struct {
    frequency_khz: u32,
    datarates: []const Datarate,
    fixed: bool = true,
    is_used: bool = true,
};

pub const EU868_870 = struct {
    // 1.0.4 value 0xF (decimal 15) of either DataRate or TXPower means that the end-device SHALL
    // ignore that field and keep the current parameter values
    // Total number of data rates is 12
    const table_datarates = [_]?Datarate{
        .{ .lora = .{ .spreading_factor = .sf12, .bandwidth = .bw125, .direction = .both } },
        .{ .lora = .{ .spreading_factor = .sf11, .bandwidth = .bw125, .direction = .both } },
        .{ .lora = .{ .spreading_factor = .sf10, .bandwidth = .bw125, .direction = .both } },
        .{ .lora = .{ .spreading_factor = .sf9, .bandwidth = .bw125, .direction = .both } },
        .{ .lora = .{ .spreading_factor = .sf8, .bandwidth = .bw125, .direction = .both } },
        .{ .lora = .{ .spreading_factor = .sf7, .bandwidth = .bw125, .direction = .both } },
        .{ .lora = .{ .spreading_factor = .sf7, .bandwidth = .bw250, .direction = .both } },
        .{ .fsk = .{ .bitrate = 50000, .direction = .both } },
        .{ .lrfhss = .{ .coding_rate = .cr1_3, .occupied_channel_width = 137000, .direction = .uplink } },
        .{ .lrfhss = .{ .coding_rate = .cr2_3, .occupied_channel_width = 137000, .direction = .uplink } },
        .{ .lrfhss = .{ .coding_rate = .cr1_3, .occupied_channel_width = 336000, .direction = .uplink } },
        .{ .lrfhss = .{ .coding_rate = .cr2_3, .occupied_channel_width = 336000, .direction = .uplink } },
        null,
        null,
        null,
        null,
    };

    const uplink_dwell_time = 1;
    const downlink_dwell_time = 1;

    const max_duty_cycle = 0;
    const max_eirp_index = 5;

    // LinkADRReq.DataRate_TXPower [3..0] 4 bit field
    const table_tx_power = [_]?u8{
        table_eirp[max_eirp_index],
        table_eirp[max_eirp_index] - 2,
        table_eirp[max_eirp_index] - 4,
        table_eirp[max_eirp_index] - 6,
        table_eirp[max_eirp_index] - 8,
        table_eirp[max_eirp_index] - 10,
        table_eirp[max_eirp_index] - 12,
        table_eirp[max_eirp_index] - 14,
        // RFU 8..15
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
    };

    // Maxium MACPayload size for datarate index 0..15
    const table_maximum_payload_size = [_]?MaxPayloadSize{
        .{ .macpayload = 59 },
        .{ .macpayload = 59 },
        .{ .macpayload = 59 },
        .{ .macpayload = 123 },
        .{ .macpayload = 230 },
        .{ .macpayload = 230 },
        .{ .macpayload = 230 },
        .{ .macpayload = 230 },
        .{ .macpayload = 58 },
        .{ .macpayload = 123 },
        .{ .macpayload = 58 },
        .{ .macpayload = 123 },
        null,
        null,
        null,
        null,
    };

    const uplink_channels = [_]Channel{
        // Fixed channels
        .{ .frequency_khz = 868100, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = true },
        .{ .frequency_khz = 868300, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = true },
        .{ .frequency_khz = 868500, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = true },
        // Extra channels
        .{ .frequency_khz = 867100, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = false },
        .{ .frequency_khz = 867500, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = false },
        .{ .frequency_khz = 867700, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = false },
        .{ .frequency_khz = 867900, .datarates = &[_]Datarate{ table_datarates[0].?, table_datarates[1].?, table_datarates[2].?, table_datarates[3].?, table_datarates[4].?, table_datarates[5].? }, .fixed = false },
        .{ .frequency_khz = 867300, .datarates = &[_]Datarate{table_datarates[6].?}, .fixed = false },
        .{ .frequency_khz = 867700, .datarates = &[_]Datarate{table_datarates[7].?}, .fixed = false },
    };
    const downlink_channels = uplink_channels;

    // LinkADRReq.Redundancy.ChMaskCntl [6..4] 3 bit field
    const table_ch_mask_cntl_value = [_]?u8{
        0,
        1,
        2,
        3,
        4,
        5,
        6,
    };
};

pub fn getUplinkChannelIndex(band: anytype, frequency_khz: u32) !u8 {
    for (band.uplink_channels, 0..) |channel, i| {
        if (channel != null) {
            if (channel.frequency_khz == frequency_khz)
                return @intCast(i);
        }
    }

    return error.ChannelNotFound;
}

pub fn getLoRaDatarateIndex(band: anytype, bw: LoRaBandwidth, sf: LoRaSpreadingFactor) !struct { index: u8, lora_datarate: LoRaDatarate } {
    for (band.table_datarates, 0..) |datarate, i| {
        if (datarate != null) {
            switch (datarate.?) {
                .lora => |lora| {
                    if (lora.bandwidth == bw and lora.spreading_factor == sf)
                        return .{
                            .index = @intCast(i),
                            .lora_datarate = lora,
                        };
                },
                else => continue,
            }
        }
    }

    return error.DatarateNotFound;
}

test "getLoRaDatarate" {
    const datarate = try getLoRaDatarateIndex(EU868_870, .bw125, .sf7);
    try std.testing.expect(datarate.index > 0);

    const i = datarate.index;
    try std.testing.expectEqual(EU868_870.table_datarates[i].?.lora.bandwidth, .bw125);
}
