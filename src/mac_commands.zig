const std = @import("std");

pub const MACCommandIdNS = enum(u8) {
    reset_conf = 0x01,
    link_check_ans = 0x02,
    link_adr_req = 0x03,
    duty_cycle_req = 0x04,
    rx_param_setup_req = 0x05,
    dev_status_req = 0x06,
    new_channel_req = 0x07,
    rx_timing_setup_req = 0x08,
    tx_param_setup_req = 0x09,
    dl_channel_req = 0x0A,
    rekey_conf = 0x0B,
    adr_param_setup_req = 0x0C,
    device_time_ans = 0x0D,
    force_rejoin_req = 0x0E,
    rejoin_param_setup_req = 0x0F,
    ping_slot_info_ans = 0x10,
    ping_slot_channel_req = 0x11,
    beacon_timing_ans = 0x12,
    beacon_freq_req = 0x13,
};

pub const MACCommandIdDevice = enum(u8) {
    reset_ind = 0x01,
    link_check_req = 0x02,
    link_adr_ans = 0x03,
    duty_cycle_ans = 0x04,
    rx_param_setup_ans = 0x05,
    dev_status_ans = 0x06,
    new_channel_ans = 0x07,
    rx_timing_setup_ans = 0x08,
    tx_param_setup_ans = 0x09,
    dl_channel_ans = 0x0A,
    rekey_ind = 0x0B,
    adr_param_setup_ans = 0x0C,
    device_time_req = 0x0D,
    rejoin_param_setup_ans = 0x0F,
    ping_slot_info_req = 0x10,
    ping_slot_channel_ans = 0x11,
    beacon_timing_req = 0x12,
    beacon_freq_ans = 0x13,
};

fn CreateEmptyMACCommand(comptime command_id: anytype) type {
    return struct {
        const size = 0;
        const id = command_id;

        fn decode(bytes: []const u8) !@This() {
            _ = bytes;
            return @This(){};
        }

        fn encode(self: @This(), result: []u8) ![]u8 {
            _ = result;
            _ = self;
            return &.{};
        }
    };
}

fn CreateNotImplementedMACCommand(comptime command_id: anytype) type {
    return struct {
        const size = 0;
        const id = command_id;

        fn decode(bytes: []const u8) !@This() {
            _ = bytes;
            @panic("MAC command implemented: " ++ @tagName(command_id) ++ "\n");
        }

        fn encode(self: @This(), result: []u8) ![]u8 {
            _ = result;
            _ = self;
            @panic("MAC command implemented: " ++ @tagName(command_id) ++ "\n");
        }
    };
}

const ResetConf = CreateNotImplementedMACCommand(MACCommandIdNS.reset_conf);
const ResetInd = CreateNotImplementedMACCommand(MACCommandIdDevice.reset_ind);

const LinkCheckReq = CreateEmptyMACCommand(MACCommandIdDevice.link_check_req);

const LinkCheckAns = packed struct {
    margin: u8,
    gw_cnt: u8,

    const size = 2;
    const id = MACCommandIdNS.link_check_ans;

    fn decode(bytes: []const u8) !LinkCheckAns {
        return @bitCast(bytes[0..2].*);
    }

    fn encode(self: LinkCheckAns, result: []u8) ![]u8 {
        result[0] = self.margin;
        result[1] = self.gw_cnt;
        return result[0..2];
    }
};

const LinkADRReq = packed struct {
    tx_power: u4,
    data_rate: u4,

    ch_mask: u16,

    nb_trans: u4,
    ch_mask_cntl: u3,
    rfu: u1,

    const size = 4;
    const id = MACCommandIdNS.link_adr_req;

    fn decode(bytes: []const u8) !LinkADRReq {
        return @bitCast(bytes[0..4].*);
    }

    fn encode(self: LinkADRReq, result: []u8) ![]u8 {
        result[0] = @as(u8, @intCast(self.data_rate)) << 4 | self.tx_power;
        result[1] = @truncate(self.ch_mask);
        result[2] = @truncate(self.ch_mask >> 8);
        result[3] = @as(u8, @intCast(self.rfu)) << 7 | @as(u8, @intCast(self.ch_mask_cntl)) << 4 | self.nb_trans;
        return result[0..4];
    }
};

const LinkADRAns = packed struct {
    ch_mask_ack: bool,
    data_rate_ack: bool,
    power_ack: bool,
    rfu: u5,

    const size = 1;
    const id = MACCommandIdDevice.link_adr_ans;

    fn decode(bytes: []const u8) !LinkADRAns {
        return @bitCast(bytes[0..1].*);
    }

    fn encode(self: LinkADRAns, result: []u8) ![]u8 {
        result[0] = @bitCast(self);
        return result[0..1];
    }
};

const DutyCycleReq = CreateNotImplementedMACCommand(MACCommandIdNS.duty_cycle_req);
const DutyCycleAns = CreateEmptyMACCommand(MACCommandIdDevice.duty_cycle_ans);
const RxParamSetupReq = CreateNotImplementedMACCommand(MACCommandIdNS.rx_param_setup_req);

const RxParamSetupAns = packed struct {
    channel_ack: bool,
    rx2_datarate_ack: bool,
    rx1_droffset_ack: bool,
    rfu: u5,

    const size = 1;
    const id = MACCommandIdDevice.rx_param_setup_ans;

    fn decode(bytes: []const u8) !RxParamSetupAns {
        return @bitCast(bytes[0..1].*);
    }

    fn encode(self: RxParamSetupAns, result: []u8) ![]u8 {
        result[0] = @bitCast(self);
        return result[0..1];
    }
};

const DevStatusReq = CreateNotImplementedMACCommand(MACCommandIdNS.dev_status_req);

const DevStatusAns = packed struct {
    battery: u8,
    margin: u8,

    const size = 2;
    const id = MACCommandIdDevice.dev_status_ans;

    fn decode(bytes: []const u8) !DevStatusAns {
        return @bitCast(bytes[0..2].*);
    }

    fn encode(self: DevStatusAns, result: []u8) ![]u8 {
        const mac_command_data: u16 = @bitCast(self);
        result[0] = @truncate(mac_command_data);
        result[1] = @truncate(mac_command_data >> 8);
        return result[0..2];
    }
};

const NewChannelReq = CreateNotImplementedMACCommand(MACCommandIdNS.new_channel_req);

const NewChannelAns = packed struct {
    channel_frequency_ok: bool,
    datarate_range_ok: bool,
    rfu: u6,

    const size = 1;
    const id = MACCommandIdDevice.new_channel_ans;

    fn decode(bytes: []const u8) !NewChannelAns {
        return @bitCast(bytes[0..1].*);
    }

    fn encode(self: NewChannelAns, result: []u8) ![]u8 {
        result[0] = @bitCast(self);
        return result[0..1];
    }
};

const RxTimingSetupReq = CreateNotImplementedMACCommand(MACCommandIdNS.rx_timing_setup_req);
const RxTimingSetupAns = CreateEmptyMACCommand(MACCommandIdDevice.rx_timing_setup_ans);
const TxParamSetupReq = CreateNotImplementedMACCommand(MACCommandIdNS.tx_param_setup_req);
const TxParamSetupAns = CreateEmptyMACCommand(MACCommandIdDevice.tx_param_setup_ans);
const DLChannelReq = CreateNotImplementedMACCommand(MACCommandIdNS.dl_channel_req);
const DLChannelAns = CreateNotImplementedMACCommand(MACCommandIdDevice.dl_channel_ans);
const RekeyConf = CreateNotImplementedMACCommand(MACCommandIdNS.rekey_conf);
const RekeyInd = CreateNotImplementedMACCommand(MACCommandIdDevice.rekey_ind);
const ADRParamSetupReq = CreateNotImplementedMACCommand(MACCommandIdNS.adr_param_setup_req);
const ADRParamSetupAns = CreateNotImplementedMACCommand(MACCommandIdDevice.adr_param_setup_ans);
const DeviceTimeReq = CreateEmptyMACCommand(MACCommandIdNS.device_time_ans);
const DeviceTimeAns = CreateNotImplementedMACCommand(MACCommandIdDevice.device_time_req);
const ForceRejoinReq = CreateNotImplementedMACCommand(MACCommandIdNS.force_rejoin_req);
const RejoinParamSetupReq = CreateNotImplementedMACCommand(MACCommandIdNS.rejoin_param_setup_req);
const RejoinParamSetupAns = CreateNotImplementedMACCommand(MACCommandIdDevice.rejoin_param_setup_ans);

const PingSlotInfoReq = packed struct {
    periodicity: u3,
    rfu: u5,

    const size = 1;
    const id = MACCommandIdDevice.ping_slot_info_req;

    fn decode(bytes: []const u8) !PingSlotInfoReq {
        return @bitCast(bytes[0..1].*);
    }

    fn encode(self: PingSlotInfoReq, result: []u8) ![]u8 {
        result[0] = @bitCast(self);
        return result[0..1];
    }
};

const PingSlotInfoAns = CreateNotImplementedMACCommand(MACCommandIdDevice.ping_slot_info_req);
const PingSlotChannelReq = CreateNotImplementedMACCommand(MACCommandIdNS.ping_slot_channel_req);

const PingSlotChannelAns = packed struct {
    channel_frequency_status: bool,
    datarate_status: bool,
    rfu: u6,

    const size = 1;
    const id = MACCommandIdDevice.ping_slot_channel_ans;

    fn decode(bytes: []const u8) !PingSlotChannelAns {
        return @bitCast(bytes[0..1].*);
    }

    fn encode(self: PingSlotChannelAns, result: []u8) ![]u8 {
        result[0] = @bitCast(self);
        return result[0..1];
    }
};

const BeaconTimingReq = CreateNotImplementedMACCommand(MACCommandIdNS.beacon_timing_ans);
const BeaconTimingAns = CreateNotImplementedMACCommand(MACCommandIdDevice.beacon_timing_req);
const BeaconFreqReq = CreateNotImplementedMACCommand(MACCommandIdNS.beacon_freq_req);

const BeaconFreqAns = packed struct {
    beacon_frequency_status: bool,
    rfu: u7,

    const size = 1;
    const id = MACCommandIdDevice.beacon_freq_ans;

    fn decode(bytes: []const u8) !BeaconFreqAns {
        return @bitCast(bytes[0..1].*);
    }

    fn encode(self: BeaconFreqAns, result: []u8) ![]u8 {
        result[0] = @bitCast(self);
        return result[0..1];
    }
};

fn CreateMACCommand(comptime T: anytype) type {
    return union(enum) {
        reset_conf: ResetConf,
        reset_ind: ResetInd,
        link_check_req: LinkCheckReq,
        link_check_ans: LinkCheckAns,
        link_adr_req: LinkADRReq,
        link_adr_ans: LinkADRAns,
        duty_cycle_req: DutyCycleReq,
        duty_cycle_ans: DutyCycleAns,
        rx_param_setup_req: RxParamSetupReq,
        rx_param_setup_ans: RxParamSetupAns,
        dev_status_req: DevStatusReq,
        dev_status_ans: DevStatusAns,
        new_channel_req: NewChannelReq,
        new_channel_ans: NewChannelAns,
        rx_timing_setup_req: RxTimingSetupReq,
        rx_timing_setup_ans: RxTimingSetupAns,
        tx_param_setup_req: TxParamSetupReq,
        tx_param_setup_ans: TxParamSetupAns,
        dl_channel_req: DLChannelReq,
        dl_channel_ans: DLChannelAns,
        rekey_conf: RekeyConf,
        rekey_ind: RekeyInd,
        adr_param_setup_req: ADRParamSetupReq,
        adr_param_setup_ans: ADRParamSetupAns,
        device_time_req: DeviceTimeReq,
        device_time_ans: DeviceTimeAns,
        force_rejoin_req: ForceRejoinReq,
        rejoin_param_setup_req: RejoinParamSetupReq,
        rejoin_param_setup_ans: RejoinParamSetupAns,
        ping_slot_info_req: PingSlotInfoReq,
        ping_slot_info_ans: PingSlotInfoAns,
        ping_slot_channel_req: PingSlotChannelReq,
        ping_slot_channel_ans: PingSlotChannelAns,
        beacon_timing_req: BeaconTimingReq,
        beacon_timing_ans: BeaconTimingAns,
        beacon_freq_req: BeaconFreqReq,
        beacon_freq_ans: BeaconFreqAns,

        const Self = @This();

        pub fn getCommandId(self: Self) u8 {
            return switch (self) {
                inline else => |mac_cmd| @intFromEnum(@TypeOf(mac_cmd).id),
            };
        }

        pub fn getCommandSize(self: Self) u8 {
            return switch (self) {
                inline else => |mac_cmd| @TypeOf(mac_cmd).size + 1,
            };
        }

        fn typeDecoder(comptime name: []const u8, comptime mac_cmd_type: anytype) type {
            return struct {
                fn decode(data: []const u8) !Self {
                    return @unionInit(Self, name, try mac_cmd_type.decode(data));
                }
            };
        }

        pub fn decode(data: []const u8) !Self {
            const fn_decode = *const fn ([]const u8) anyerror!Self;

            const mac_commands = comptime blk: {
                @setEvalBranchQuota(2000);

                const self_fields = std.meta.fields(Self);
                const enum_fields = std.meta.fields(T);

                var max_command_id: u8 = 0;
                for (self_fields) |field| {
                    max_command_id = @max(@intFromEnum(field.type.id), max_command_id);
                }
                const Item = struct { size: u8, decode: fn_decode };
                // map: mac_command_id[u8] -> mac_command decoder function
                var map = [_]?Item{null} ** (max_command_id + 1);

                for (enum_fields) |field| {
                    const self_field_index = std.meta.fieldIndex(Self, field.name).?;
                    const mac_cmd_type = self_fields[self_field_index].type;
                    const decoder = typeDecoder(field.name, mac_cmd_type);
                    map[field.value] = .{ .decode = &decoder.decode, .size = mac_cmd_type.size };
                }
                break :blk map;
            };

            if (data.len == 0)
                return error.InvalidBufferLength;

            const command_id = data[0];
            if (command_id >= mac_commands.len)
                return error.InvalidMACCommand;

            if (mac_commands[command_id] == null)
                return error.InvalidMACCommand;

            const mac_command = mac_commands[command_id].?;
            if (mac_command.size == 0)
                return mac_command.decode(&.{});

            if (data.len < mac_command.size)
                return error.InvalidBufferLength;

            return mac_command.decode(data[1..]);
        }

        pub fn encode(self: @This(), result: []u8) ![]u8 {
            switch (self) {
                inline else => |mac_cmd| {
                    const mac_cmd_type = @TypeOf(mac_cmd);
                    const mac_cmd_id = @intFromEnum(mac_cmd_type.id);

                    if (result.len < mac_cmd_type.size + 1)
                        return error.InvalidBufferLength;

                    result[0] = mac_cmd_id;
                    //if (mac_cmd_type.size == 0)
                    //    return result[0..1];

                    const mac_command_payload = try mac_cmd.encode(result[1..]);
                    return result[0 .. 1 + mac_command_payload.len];
                },
            }
        }
    };
}

pub const MACCommandNS = CreateMACCommand(MACCommandIdNS);
pub const MACCommandDevice = CreateMACCommand(MACCommandIdDevice);

fn CreateMACCommandList(comptime T: anytype) type {
    return struct {
        buffer: [255]T = undefined,
        commands: []T = undefined,
        size: usize = 0,

        const max_mac_command_size = 15;

        pub fn add(self: *@This(), command: T) !void {
            if (self.commands.len == self.buffer.len)
                return error.BufferOverflow;

            self.size += command.getCommandSize();
            self.buffer[self.commands.len] = command;
            self.commands = self.buffer[0 .. self.commands.len + 1];
        }

        pub fn clear(self: *@This()) void {
            self.size = 0;
            self.commands = self.buffer[0..0];
        }

        pub fn encode(self: *@This(), result: []u8) ![]u8 {
            var current_data_offset = 0;

            for (self.commands) |mac_command| {
                var buffer: [max_mac_command_size]u8 = undefined;
                const mac_command_encoded = try mac_command.encode(&buffer);
                if (result.len < current_data_offset + mac_command_encoded.len)
                    return error.InvalidBufferLength;

                @memcpy(result[current_data_offset..], mac_command_encoded);
                current_data_offset += mac_command_encoded.len;
            }

            return result;
        }

        pub fn decode(data: []const u8) !@This() {
            var mac_commands_list = @This(){};
            var current_data_offset: usize = 0;

            while (current_data_offset < data.len) {
                var mac_command = try T.decode(data[current_data_offset..]);
                try mac_commands_list.add(mac_command);
                current_data_offset += mac_command.getCommandSize();
            }

            return mac_commands_list;
        }
    };
}

pub const MACCommandListNS = CreateMACCommandList(MACCommandNS);
pub const MACCommandListDevice = CreateMACCommandList(MACCommandDevice);

test "MACCommand: getCommandId" {
    const mac_cmd_data_received = [_]u8{ 0x02, 0x01, 0x02 };
    var mac_cmd = MACCommandNS.decode(&mac_cmd_data_received) catch unreachable;
    try std.testing.expectEqual(mac_cmd.getCommandId(), 0x02);
}

test "mac_command: LinkCheckReq" {
    const mac_cmd_data_received = [_]u8{0x02};
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;
    try std.testing.expect(std.meta.activeTag(mac_command) == .link_check_req);

    var buffer = [_]u8{0};
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: LinkCheckAns" {
    const mac_cmd_data_received = [_]u8{ 0x02, 0x01, 0x02 };
    var mac_command_ns = MACCommandNS.decode(&mac_cmd_data_received) catch unreachable;

    const link_check_ans = mac_command_ns.link_check_ans;
    try std.testing.expectEqual(link_check_ans.margin, 0x01);
    try std.testing.expectEqual(link_check_ans.gw_cnt, 0x02);

    var buffer = [_]u8{ 0, 0, 0 };
    const mac_cmd_data_encoded = mac_command_ns.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: LinkADRReq" {
    const mac_cmd_data_received = [_]u8{ 0x03, 0x21, 0xfb, 0xfa, 0x54 };
    var mac_command = MACCommandNS.decode(&mac_cmd_data_received) catch unreachable;

    // tx_power=1, datarate=2, ch_mask=0xFAFB, nb_trans=4, ch_mask_cntl=5
    const link_adr_req = mac_command.link_adr_req;
    try std.testing.expectEqual(link_adr_req.tx_power, 0x01);
    try std.testing.expectEqual(link_adr_req.data_rate, 0x02);
    try std.testing.expectEqual(link_adr_req.ch_mask, 0xFAFB);
    try std.testing.expectEqual(link_adr_req.nb_trans, 0x04);
    try std.testing.expectEqual(link_adr_req.ch_mask_cntl, 0x05);
    try std.testing.expectEqual(link_adr_req.rfu, 0x00);

    var buffer = [_]u8{ 0, 0, 0, 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: LinkADRAns" {
    const mac_cmd_data_received = [_]u8{ 0x03, 0x04 };
    // channel_mask_ack=False, datarate_ack=False, power_ack=True
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const link_adr_ans = mac_command.link_adr_ans;
    try std.testing.expectEqual(link_adr_ans.ch_mask_ack, false);
    try std.testing.expectEqual(link_adr_ans.data_rate_ack, false);
    try std.testing.expectEqual(link_adr_ans.power_ack, true);

    var buffer = [_]u8{ 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: DevStatusAns" {
    // battery=254, margin=50
    const mac_cmd_data_received = [_]u8{ 0x06, 0xfe, 0x12 };
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const dev_status_ans = mac_command.dev_status_ans;
    try std.testing.expectEqual(dev_status_ans.battery, 0xfe);
    try std.testing.expectEqual(dev_status_ans.margin, 0x12);

    var buffer = [_]u8{ 0, 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: RXParamSetupAns" {
    // (channel_ack=True, rx2_datarate_ack=True, rx1_datarate_offset_ack=False
    const mac_cmd_data_received = [_]u8{ 0x05, 0x03 };
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const rx_param_setup_ans = mac_command.rx_param_setup_ans;
    try std.testing.expectEqual(rx_param_setup_ans.channel_ack, true);
    try std.testing.expectEqual(rx_param_setup_ans.rx1_droffset_ack, false);
    try std.testing.expectEqual(rx_param_setup_ans.rx2_datarate_ack, true);

    var buffer = [_]u8{ 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: NewChannelAns" {
    // channel_frequency_ok = False, datarate_range_ok=Tru
    const mac_cmd_data_received = [_]u8{ 0x07, 0x02 };
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const new_channel_ans = mac_command.new_channel_ans;
    try std.testing.expectEqual(new_channel_ans.channel_frequency_ok, false);
    try std.testing.expectEqual(new_channel_ans.datarate_range_ok, true);

    var buffer = [_]u8{ 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: PingSlotInfoReq" {
    // periodicity=0x01, rfus=0x00
    const mac_cmd_data_received = [_]u8{ 0x10, 0x07 };
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const ping_slot_info_req = mac_command.ping_slot_info_req;
    try std.testing.expectEqual(ping_slot_info_req.periodicity, 0x07);
    try std.testing.expectEqual(ping_slot_info_req.rfu, 0x00);

    var buffer = [_]u8{ 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: PingSlotChannelAns" {
    // datarate_status=False, channel_frequency_status=True
    const mac_cmd_data_received = [_]u8{ 0x11, 0x01 };
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const ping_slot_channel_ans = mac_command.ping_slot_channel_ans;
    try std.testing.expectEqual(ping_slot_channel_ans.channel_frequency_status, true);
    try std.testing.expectEqual(ping_slot_channel_ans.datarate_status, false);

    var buffer = [_]u8{ 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "mac_command: BeaconFreqAns" {
    // datarate_status=False, channel_frequency_status=True
    const mac_cmd_data_received = [_]u8{ 0x13, 0x01 };
    var mac_command = MACCommandDevice.decode(&mac_cmd_data_received) catch unreachable;

    const beacon_freq_ans = mac_command.beacon_freq_ans;
    try std.testing.expectEqual(beacon_freq_ans.beacon_frequency_status, true);

    var buffer = [_]u8{ 0, 0 };
    const mac_cmd_data_encoded = mac_command.encode(&buffer) catch unreachable;
    try std.testing.expectEqualSlices(u8, &mac_cmd_data_received, mac_cmd_data_encoded);
}

test "MACCommandList" {
    const mac_cmds_data_received = [_]u8{
        0x03, 0x04, // LinkADRAns
        0x06, 0xfe, 0x12, // DevStatusAns
        0x02, // LinkCheckReq
    };
    var mac_commands_list = try MACCommandListDevice.decode(&mac_cmds_data_received);
    try std.testing.expectEqual(mac_commands_list.commands.len, 3);

    try std.testing.expectEqual(std.meta.activeTag(mac_commands_list.commands[0]), .link_adr_ans);
    try std.testing.expectEqual(std.meta.activeTag(mac_commands_list.commands[1]), .dev_status_ans);
    try std.testing.expectEqual(std.meta.activeTag(mac_commands_list.commands[2]), .link_check_req);

    // Test clear
    mac_commands_list.clear();
    try std.testing.expectEqual(mac_commands_list.commands.len, 0);

    // Test bad buffer length
    const bad_mac_cmds_data_received = [_]u8{
        0x03, 0x04, // LinkADRAns
        0x06,
    };

    const r = MACCommandListDevice.decode(&bad_mac_cmds_data_received);
    try std.testing.expectError(error.InvalidBufferLength, r);
}
