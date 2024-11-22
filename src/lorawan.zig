const std = @import("std");
const aes = std.crypto.core.aes;
const cmac = std.crypto.auth.cmac;

pub const LoRaWAN_MessageType = enum(u3) {
    join_request = 0x00, // LoRaWAN Join Request
    join_accept = 0x01, // LoRaWAN JoinAccept
    unconfirmed_data_up = 0x02, // LoRaWAN UnconfirmedDataUp
    unconfirmed_data_down = 0x03, // LoRaWAN UnconfirmedDataDown
    confirmed_data_up = 0x04, // LoRaWAN ConfirmedDataUp
    confirmed_data_down = 0x05, // LoRaWAN ConfirmedDataDown
    rfu = 0x06, // LoRaWAN RFU
    proprietary = 0x07, // LoRaWAN Proprietary
};

// LoRaWAN Major Version Enumeration
pub const LoRaWAN_MajorVersion = enum(u2) {
    lorawan_r1 = 0x00, // LoRaWAN R1
    rfu_1 = 0x01, // Reserved for future use
    rfu_2 = 0x02, // Reserved for future use
    rfu_3 = 0x03, // Reserved for future use
};

// LoRaWAN Message Header (MHDR)
pub const LoRaWAN_MHDR = packed struct {
    // In reverse order because of bit order
    major: LoRaWAN_MajorVersion, // Major Version
    rfu: u3, // RFU
    mtype: LoRaWAN_MessageType, // Message Type

    pub fn isDataMessage(self: *LoRaWAN_MHDR) bool {
        switch (self.mtype) {
            .unconfirmed_data_up, .unconfirmed_data_down, .confirmed_data_up, .confirmed_data_down => return true,
            else => return false,
        }
    }

    pub fn decode(bytes: []const u8) !LoRaWAN_MHDR {
        if (bytes.len < 1)
            return error.InvalidMessageHeader;

        return @bitCast(bytes[0]);
    }

    pub fn encode(self: *LoRaWAN_MHDR, result: []u8) []u8 {
        result[0] = @bitCast(self.*);
        return result[0..1];
    }

    pub fn getSize(self: *LoRaWAN_MHDR) usize {
        return @sizeOf(@TypeOf(self.*));
    }
};

// LoRaWAN Frame Control (FCtrl) for uplinks
pub const LoRaWAN_FCtrlUplink = packed struct {
    // In reverse order because of bit order
    fopts_len: u4, // Frame options length
    class_b: bool, // Frame pending
    ack: bool, // Acknowledge
    adr_ack_req: bool, // ADR acknowledgement request
    adr: bool, // Adaptive Data Rate

    pub fn decode(bytes: []const u8) !LoRaWAN_FCtrlUplink {
        if (bytes.len < 1)
            return error.InvalidFrameControl;

        return @bitCast(bytes[0]);
    }

    pub fn encode(self: *const LoRaWAN_FCtrlUplink, result: []u8) []u8 {
        result[0] = @bitCast(self.*);
        return result[0..1];
    }
};

// LoRaWAN Frame Control (FCtrl) for downlinks
pub const LoRaWAN_FCtrlDownlink = packed struct {
    // In reverse order because of bit order
    fopts_len: u4, // Frame options length
    fpending: bool, // Frame pending
    ack: bool, // Acknowledge
    rfu: bool, // RFU
    adr: bool, // Adaptive Data Rate

    pub fn decode(bytes: []const u8) !LoRaWAN_FCtrlDownlink {
        if (bytes.len < 1)
            return error.InvalidFrameControl;

        return @bitCast(bytes[0]);
    }

    pub fn encode(self: *const LoRaWAN_FCtrlDownlink, result: []u8) []u8 {
        result[0] = @bitCast(self.*);
        return result[0..1];
    }
};

// LoRaWAN Frame Header (FHDR)
pub const LoRaWAN_FHDR = struct {
    dev_addr: u32, // Device Address (4 bytes)
    fctrl: union(enum) { // Frame Control (1 byte)
        fctrl_uplink: LoRaWAN_FCtrlUplink,
        fctrl_downlink: LoRaWAN_FCtrlDownlink,
    },
    fcnt: u32, // Frame Counter (2 bytes)
    fopts: []const u8, // Frame options (variable length)

    fopts_buffer: [15]u8 = undefined, // Frame options buffer

    pub fn decode(msg_type: LoRaWAN_MessageType, bytes: []const u8) !LoRaWAN_FHDR {
        if (bytes.len < 7)
            return error.InvalidFrameHeader;

        var fopt_len: u8 = 0;
        var fhdr: LoRaWAN_FHDR = undefined;
        fhdr.dev_addr = std.mem.readPackedInt(u32, bytes[0..4], 0, .little);
        fhdr.fctrl = blk: {
            if (msg_type == .unconfirmed_data_up or msg_type == .unconfirmed_data_down) {
                const fctrl_uplink = try LoRaWAN_FCtrlUplink.decode(bytes[4..5]);
                fopt_len = fctrl_uplink.fopts_len;
                break :blk .{ .fctrl_uplink = fctrl_uplink };
            } else if (msg_type == .confirmed_data_up or msg_type == .confirmed_data_down) {
                const fctrl_downlink = try LoRaWAN_FCtrlDownlink.decode(bytes[4..5]);
                fopt_len = fctrl_downlink.fopts_len;
                break :blk .{ .fctrl_downlink = fctrl_downlink };
            } else {
                return error.InvalidMessageType;
            }
        };

        fhdr.fcnt = std.mem.readPackedInt(u16, bytes[5..7], 0, .little);

        const frame_end_index = 7 + fopt_len;
        if (frame_end_index >= bytes.len or fopt_len > 15)
            return error.InvalidFrameHeader;

        std.mem.copyForwards(u8, &fhdr.fopts_buffer, bytes[7..frame_end_index]);
        fhdr.fopts = fhdr.fopts_buffer[0..fopt_len];
        return fhdr;
    }

    pub fn encode(self: *LoRaWAN_FHDR, result: []u8) []u8 {
        var fopt_len: u8 = 0;

        std.mem.writeInt(u32, result[0..4], self.dev_addr, .little);

        switch (self.fctrl) {
            .fctrl_uplink => |fctrl| {
                _ = fctrl.encode(result[4..5]);
                fopt_len = fctrl.fopts_len;
            },
            .fctrl_downlink => |fctrl| {
                _ = fctrl.encode(result[4..5]);
                fopt_len = fctrl.fopts_len;
            },
        }

        std.mem.writeInt(u16, result[5..7], @as(u16, @truncate(self.fcnt)), .little);
        std.mem.copyForwards(u8, result[7..], self.fopts);

        return result[0 .. 7 + fopt_len];
    }

    pub fn getSize(self: *const LoRaWAN_FHDR) usize {
        // 4 bytes for devAddr, 1 byte for fCtrl, 2 bytes for fcnt and fOptsLen bytes (variable)
        var fopts_len: usize = 0;
        switch (self.fctrl) {
            .fctrl_uplink => |fctrl| fopts_len = fctrl.fopts_len,
            .fctrl_downlink => |fctrl| fopts_len = fctrl.fopts_len,
        }
        return 7 + fopts_len;
    }

    pub fn syncBuffer(self: *LoRaWAN_FHDR) void {
        std.mem.copyForwards(u8, &self.fopts_buffer, self.fopts);
        self.fopts = self.fopts_buffer[0..self.fopts.len];
    }
};

// LoRaWAN Join Request
pub const LoRaWAN_JoinRequest = struct {
    app_eui: [8]u8, // Application EUI
    dev_eui: [8]u8, // Device EUI
    dev_nonce: u16, // Device Nonce

    pub fn decode(bytes: []const u8) !LoRaWAN_JoinRequest {
        // Minimal length of a Join Request is 18 bytes
        // AppEUI (8 bytes) + DevEUI (8 bytes) + DevNonce (2 bytes)
        if (bytes.len < 18)
            return error.InvalidJoinRequest;

        return LoRaWAN_JoinRequest{
            .app_eui = bytes[0..8].*,
            .dev_eui = bytes[8..16].*,
            .dev_nonce = std.mem.readPackedInt(u16, bytes[16..18], 0, .little),
        };
    }

    pub fn encode(self: *LoRaWAN_JoinRequest, result: []u8) []u8 {
        std.mem.copyForwards(u8, result[0..8], &self.app_eui);
        std.mem.copyForwards(u8, result[8..16], &self.dev_eui);
        std.mem.writeInt(u16, result[16..18], self.dev_nonce, .little);
        return result[0..18];
    }

    pub fn getSize(self: *LoRaWAN_JoinRequest) usize {
        // 8 bytes for AppEUI, 8 bytes for DevEUI and 2 bytes for DevNonce
        return self.app_eui.len + self.dev_eui.len + @sizeOf(@TypeOf(self.dev_nonce));
    }
};

// LoRaWAN Join Accept
pub const LoRaWAN_JoinAccept = struct {
    app_nonce: u24, // Application Nonce (3 bytes)
    net_id: u24, // Network ID (3 bytes)
    dev_addr: u32, // Device Address (4 bytes)
    dl_settings: u8, // Downlink Settings (1 byte)
    rx_delay: u8, // Receive Delay 1 (1 byte)
    cf_list: []const u8, // Channel Frequency List (optional)

    cf_list_buffer: [16]u8 = undefined, // Buffer for CFList

    pub fn decode(bytes: []const u8) !LoRaWAN_JoinAccept {
        // Minimal size of a Join Accept is 12 bytes
        // AppNonce (3 bytes) + NetID (3 bytes) + DevAddr (4 bytes) + DLSettings (1 byte) + RxDelay (1 byte) + CFList (optional)
        const minimal_size = 12;
        if (bytes.len < minimal_size)
            return error.InvalidJoinAccept;

        var lorawan_join_accept: LoRaWAN_JoinAccept = undefined;
        lorawan_join_accept.app_nonce = std.mem.readPackedInt(u24, bytes[0..3], 0, .little);
        lorawan_join_accept.net_id = std.mem.readPackedInt(u24, bytes[3..6], 0, .little);
        lorawan_join_accept.dev_addr = std.mem.readPackedInt(u32, bytes[6..10], 0, .little);
        lorawan_join_accept.dl_settings = bytes[10];
        lorawan_join_accept.rx_delay = bytes[11];

        const max_cf_list_len = 16;
        if (bytes.len > minimal_size) {
            // CFList is optional and can be 16 bytes long
            const remaining_size = bytes.len - minimal_size;
            if (remaining_size > max_cf_list_len)
                return error.InvalidJoinAccept;

            const cf_list = bytes[minimal_size .. minimal_size + remaining_size];
            std.mem.copyForwards(u8, &lorawan_join_accept.cf_list_buffer, cf_list);
            lorawan_join_accept.cf_list = lorawan_join_accept.cf_list_buffer[0..cf_list.len];
        }

        return lorawan_join_accept;
    }

    pub fn encode(self: *LoRaWAN_JoinAccept, result: []u8) []u8 {
        std.mem.writeInt(u24, result[0..3], self.app_nonce, .little);
        std.mem.writeInt(u24, result[3..6], self.net_id, .little);
        std.mem.writeInt(u32, result[6..10], self.dev_addr, .little);
        result[10] = self.dl_settings;
        result[11] = self.rx_delay;

        if (self.cf_list.len > 0) {
            std.mem.copyForwards(u8, result[12..], self.cf_list);
            return result[0..28];
        }

        return result[0..12];
    }

    pub fn getSize(self: *LoRaWAN_JoinAccept) usize {
        // 3 + 3 + 4 + 1 + 1 + (16)
        if (self.cf_list) |cf_list| {
            return 12 + cf_list.len;
        }
        return 12;
    }

    pub fn syncBuffer(self: *LoRaWAN_FHDR) void {
        std.mem.copy(u8, &self.fopts_buffer, self.fopts);
        self.fopts = self.fopts_buffer[0..self.fopts.len];
    }
};

// LoRaWAN Data message
pub const LoRaWAN_DataMessage = struct {
    fhdr: LoRaWAN_FHDR, // Frame Header
    fport: ?u8, // Frame Port
    frmpayload: []const u8, // Frame Payload

    frmpayload_buffer: [255]u8 = undefined, // Buffer for Frame Payload. 255 = max message size

    pub fn decode(msg_type: LoRaWAN_MessageType, bytes: []const u8) !LoRaWAN_DataMessage {
        // Minimal length of a Data message is 7 bytes
        // FHDR (7 bytes) + PORT (0 byte) + FramePayload (0 byte)
        if (bytes.len < 7)
            return error.InvalidDataMessage;

        var lorawan_data_message: LoRaWAN_DataMessage = undefined;
        lorawan_data_message.fhdr = try LoRaWAN_FHDR.decode(msg_type, bytes[0..]);

        const fopts_end_index = lorawan_data_message.fhdr.fopts.len + 7;
        const remaining_length = bytes.len - (fopts_end_index + 1);

        // Check if remaining length = 0 only MIC(4 bytes) is present
        if (remaining_length == 0)
            return lorawan_data_message;

        // fPort (1 byte) + FramePayload(1 byte)
        if (remaining_length < 2)
            return error.InvalidDataMessage;

        lorawan_data_message.fport = bytes[fopts_end_index];

        // frmpayload
        const frmpayload = bytes[fopts_end_index + 1 .. bytes.len];
        std.mem.copyForwards(u8, &lorawan_data_message.frmpayload_buffer, frmpayload);
        lorawan_data_message.frmpayload = lorawan_data_message.frmpayload_buffer[0..frmpayload.len];

        return lorawan_data_message;
    }

    pub fn encode(self: *LoRaWAN_DataMessage, result: []u8) []u8 {
        var index: usize = 0;
        index += self.fhdr.encode(result[index..]).len;

        if (self.fport) |fport| {
            result[index] = fport;
            index += 1;
        }

        std.mem.copyForwards(u8, result[index..], self.frmpayload);
        index += self.frmpayload.len;

        return result[0..index];
    }

    fn initBlockA(self: *LoRaWAN_DataMessage, block_a: *[16]u8) void {
        block_a[0] = 0x01; // magic number
        block_a[1] = 0x00; // unused
        block_a[2] = 0x00; // unused
        block_a[3] = 0x00; // unused
        block_a[4] = 0x00; // unused

        // direction (0 = uplink, 1 = downlink)
        block_a[5] = switch (self.fhdr.fctrl) {
            .fctrl_uplink => 0x00,
            .fctrl_downlink => 0x01,
        };
        // 6..9 = devAddr
        std.mem.writePackedIntNative(u32, block_a[6..10], 0, self.fhdr.dev_addr);

        // 10..13 = fCnt
        std.mem.writePackedIntNative(u32, block_a[10..14], 0, self.fhdr.fcnt);

        block_a[14] = 0x00; // Unused
        block_a[15] = 0x00; // I
    }

    pub fn getDecryptedPayload(self: *LoRaWAN_DataMessage, key: [16]u8, out: []u8) !void {
        const block_size = key.len;

        if (out.len < self.frmpayload.len)
            return error.InvalidBufferLength;

        var block_a = [_]u8{0} ** 16;
        self.initBlockA(&block_a);

        var ctx = aes.Aes128.initEnc(key);

        // decrypt using aes128
        var encrypt_block = [_]u8{0} ** 16;
        const num_blocks = (self.frmpayload.len + block_size - 1) / block_size;

        for (0..num_blocks) |i| {
            block_a[15] = @as(u8, @intCast(i)) + 1;
            ctx.encrypt(&encrypt_block, block_a[0..block_size]);

            const start = i * block_size;
            const end = @min(self.frmpayload.len, (i + 1) * block_size);

            // XOR the encrypted block with the payload
            std.mem.copyForwards(u8, out[start..end], self.frmpayload[start..end]);
            for (out[start..end], 0..) |*byte, j| {
                byte.* ^= encrypt_block[j];
            }
        }
    }

    pub fn getEncryptedPayload(self: *LoRaWAN_DataMessage, key: [16]u8, out: []u8) !void {
        try self.getDecryptedPayload(key, out);
    }

    pub fn encrypt(self: *LoRaWAN_DataMessage, key: [16]u8) !void {
        self.syncBuffer();
        try self.getEncryptedPayload(key, &self.frmpayload_buffer);
        self.frmpayload = self.frmpayload_buffer[0..self.frmpayload.len];
    }

    pub fn decrypt(self: *LoRaWAN_DataMessage, key: [16]u8) !void {
        return self.encrypt(key);
    }

    pub fn getSize(self: *LoRaWAN_DataMessage) usize {
        var size: usize = 0;
        size += self.fhdr.getSize();
        if (self.fport) |_|
            size += 1;
        size += self.frmpayload.len;
        return size;
    }

    pub fn syncBuffer(self: *LoRaWAN_DataMessage) void {
        self.fhdr.syncBuffer();
        std.mem.copyForwards(u8, &self.frmpayload_buffer, self.frmpayload);
        self.frmpayload = self.frmpayload_buffer[0..self.frmpayload.len];
    }
};

// LoRaWAN MAC Payload (MACPayload)
pub const LoRaWAN_MACPayload = union(enum) {
    join_request: LoRaWAN_JoinRequest,
    join_accept: LoRaWAN_JoinAccept,
    data_message: LoRaWAN_DataMessage,
};

// LoRaWAN Message
pub const LoRaWAN_Message = struct {
    mhdr: LoRaWAN_MHDR, // Message Header
    mac_payload: LoRaWAN_MACPayload, // MAC Payload
    mic: u32, // Message Integrity Code

    const max_message_size = 255;

    pub fn decode(bytes: []const u8) !LoRaWAN_Message {
        // Minimum LoRaWAN message length is 12 bytes (Data message)
        // MHDR(1 byte) + FHDR(7 bytes) + FPort(0 byte) + FramePayload(0 byte) + MIC(4 bytes)
        if (bytes.len < 12)
            return error.InvalidMessage;

        if (bytes.len > max_message_size)
            return error.InvalidMessage;

        var lorawan_message: LoRaWAN_Message = undefined;
        lorawan_message.mhdr = try LoRaWAN_MHDR.decode(bytes[0..1]);

        const mic_bytes = bytes[(bytes.len - 4)..bytes.len];
        lorawan_message.mic = std.mem.readPackedInt(u32, mic_bytes[0..4], 0, .big);

        const mac_payload = bytes[1 .. bytes.len - 4];

        if (lorawan_message.mhdr.isDataMessage()) {
            const data_message = try LoRaWAN_DataMessage.decode(lorawan_message.mhdr.mtype, mac_payload);
            lorawan_message.mac_payload = .{ .data_message = data_message };
        } else if (lorawan_message.mhdr.mtype == .join_request) {
            const join_request = try LoRaWAN_JoinRequest.decode(mac_payload);
            lorawan_message.mac_payload = .{ .join_request = join_request };
        } else if (lorawan_message.mhdr.mtype == .join_accept) {
            const join_accept = try LoRaWAN_JoinAccept.decode(mac_payload);
            lorawan_message.mac_payload = .{ .join_accept = join_accept };
        } else {
            return error.InvalidMessageType;
        }

        return lorawan_message;
    }

    pub fn encode(self: *LoRaWAN_Message, result: []u8) []u8 {
        var buffer_offset: usize = 0;
        buffer_offset += self.mhdr.encode(result[buffer_offset..]).len;

        if (self.mhdr.isDataMessage()) {
            buffer_offset += self.mac_payload.data_message.encode(result[buffer_offset..]).len;
        } else if (self.mhdr.mtype == .join_request) {
            buffer_offset += self.mac_payload.join_request.encode(result[buffer_offset..]).len;
        } else if (self.mhdr.mtype == .join_accept) {
            buffer_offset += self.mac_payload.join_accept.encode(result[buffer_offset..]).len;
        }

        var mic_buffer = result[buffer_offset..];
        std.mem.writeInt(u32, mic_buffer[0..4], self.mic, .big);
        buffer_offset += 4;

        return result[0..buffer_offset];
    }

    fn initBlockB(self: *LoRaWAN_Message, block_b: *[16]u8) void {
        block_b[0] = 0x49; // magic number
        block_b[1] = 0x00; // unused
        block_b[2] = 0x00; // unused
        block_b[3] = 0x00; // unused
        block_b[4] = 0x00; // unused

        // direction (0 = uplink, 1 = downlink)
        block_b[5] = switch (self.mhdr.mtype) {
            .unconfirmed_data_up, .confirmed_data_up => 0x00,
            .unconfirmed_data_down, .confirmed_data_down => 0x01,
            else => unreachable,
        };
        // 6..9 = devAddr
        std.mem.writeInt(u32, block_b[6..10], self.mac_payload.data_message.fhdr.dev_addr, .little);

        // 10..13 = fCnt
        std.mem.writeInt(u32, block_b[10..14], self.mac_payload.data_message.fhdr.fcnt, .little);

        block_b[14] = 0x00; // Unused

        // MHDR(1 byte) + DataMessage
        block_b[15] = @intCast(self.mhdr.getSize() + self.mac_payload.data_message.getSize());
    }

    pub fn calculateMIC(self: *LoRaWAN_Message, key: [16]u8) u32 {
        var mic: [16]u8 = undefined;
        var encryption_buffer: [LoRaWAN_Message.max_message_size]u8 = [_]u8{0} ** LoRaWAN_Message.max_message_size;
        var buffer_offset: usize = 0;

        if (self.mhdr.isDataMessage()) {
            var block_b: [16]u8 = undefined;
            self.initBlockB(&block_b);

            buffer_offset = block_b.len;

            // encrypt: block_b_0 + mhdr + datamessage
            std.mem.copyForwards(u8, encryption_buffer[0..block_b.len], &block_b);
            buffer_offset += self.mhdr.encode(encryption_buffer[buffer_offset .. buffer_offset + 1]).len;
            buffer_offset += self.mac_payload.data_message.encode(encryption_buffer[buffer_offset..]).len;
        } else if (self.mhdr.mtype == .join_request or self.mhdr.mtype == .join_accept) {
            buffer_offset += self.mhdr.encode(encryption_buffer[0..1]).len;
            buffer_offset += switch (self.mhdr.mtype) {
                .join_request => self.mac_payload.join_request.encode(encryption_buffer[buffer_offset..]).len,
                .join_accept => self.mac_payload.join_accept.encode(encryption_buffer[buffer_offset..]).len,
                else => unreachable,
            };
        } else {
            return 0;
        }

        cmac.CmacAes128.create(&mic, encryption_buffer[0..buffer_offset], &key);
        return std.mem.readPackedInt(u32, mic[0..4], 0, .big);
    }

    pub fn setMIC(self: *LoRaWAN_Message, key: [16]u8) void {
        self.mic = self.calculateMIC(key);
    }

    pub fn checkMIC(self: *LoRaWAN_Message, key: [16]u8) bool {
        return self.mic == self.calculateMIC(key);
    }

    pub fn syncBuffer(self: *LoRaWAN_Message) void {
        if (self.mhdr.isDataMessage()) {
            self.mac_payload.data_message.syncBuffer();
        } else if (self.mhdr.mtype == .join_request) {
            self.mac_payload.join_request.syncBuffer();
        } else if (self.mhdr.mtype == .join_accept) {
            self.mac_payload.join_accept.syncBuffer();
        }
    }
};

test "test decrypt" {
    const app_s_key = [16]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 };
    const nwk_s_key = [16]u8{ 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22 };

    const bytes = [_]u8{
        0x40, 0xa1, 0xb2, 0x83, 0xfa, 0x80, 0x01, 0x00, 0x01, 0xd2, 0xda, 0x3d, 0xf4, 0x1c, 0xef, 0x6a,
        0xe3, 0x66, 0xc5, 0x5f, 0xea, 0x4b, 0xc4, 0x7f, 0xdd, 0x81, 0xa2, 0x61, 0x28, 0xfb, 0x70, 0x47,
        0xe6, 0x05, 0xce, 0x77, 0x70, 0xcc, 0xa2, 0x5f, 0x47, 0xc9, 0xdf, 0x59, 0xd9, 0x82, 0xbc, 0xc8,
        0x87, 0xbc, 0x73, 0xaf, 0x77, 0x12, 0xf9, 0x18, 0x61, 0xc4, 0x11, 0x67, 0x75, 0xf1, 0xee, 0x9b,
        0x3c, 0x80, 0xab, 0x04, 0xdb, 0x23, 0x2d, 0xc8, 0x4a, 0xca, 0xe4, 0x40, 0x5b, 0x11, 0x72, 0x53,
        0x11, 0x94, 0x43, 0x30, 0x20, 0x76, 0xf7, 0x45, 0x14, 0x8c, 0x86, 0xea, 0xc3, 0x44, 0xe5, 0x9d,
        0x43, 0x47, 0x19, 0x7f, 0xc9, 0xa1, 0xdc, 0xc5, 0xd0, 0xff, 0x48, 0x94, 0xaa, 0x00, 0xc7, 0x23,
        0x7e,
    };

    var lorawan_message = try LoRaWAN_Message.decode(&bytes);
    try std.testing.expectEqual(
        0xFA83B2A1,
        lorawan_message.mac_payload.data_message.fhdr.dev_addr,
    );
    try std.testing.expectEqual(
        0x01,
        lorawan_message.mac_payload.data_message.fhdr.fcnt,
    );

    // decrypt
    var buffer = [_]u8{0} ** 255;
    try lorawan_message.mac_payload.data_message.getDecryptedPayload(app_s_key, &buffer);
    for (0..100) |i| {
        try std.testing.expectEqual(buffer[i], @as(u8, @intCast(i)));
    }

    // mic check
    const mic = lorawan_message.calculateMIC(nwk_s_key);
    const expected_mic = 0x00C7237E; // 13050750
    try std.testing.expectEqual(expected_mic, mic);
}

test "parse lorawan data message" {
    const bytes = [_]u8{
        0x40, 0xB4, 0xAA, 0xAA, 0xAA, 0xA0, 0xFA, 0xAE, 0xAB, 0x0B, 0x94, 0x4D,
        0xC0, 0xB6, 0xB1, 0x0B, 0x38, 0x00, 0x38, 0x19, 0x6C, 0x24, 0x37, 0xC2,
        0xFD, 0x74, 0xDC, 0xB9, 0xFD, 0x5B, 0xEE, 0x8D, 0x3C, 0x7F, 0xBD, 0xEB,
        0xD5, 0xF0,
    };

    var lorawan_message = try LoRaWAN_Message.decode(&bytes);
    try std.testing.expectEqual(lorawan_message.mhdr.mtype, LoRaWAN_MessageType.unconfirmed_data_up);
    try std.testing.expectEqual(lorawan_message.mhdr.rfu, 0);
    try std.testing.expectEqual(lorawan_message.mhdr.major, LoRaWAN_MajorVersion.lorawan_r1);

    const fhdr = lorawan_message.mac_payload.data_message.fhdr;
    const fctrl = fhdr.fctrl.fctrl_uplink;
    try std.testing.expectEqual(fhdr.fcnt, 0xAEFA);
    try std.testing.expectEqual(fhdr.dev_addr, 0xAAAAAAB4);
    try std.testing.expectEqual(fctrl.fopts_len, 0);

    const fport = lorawan_message.mac_payload.data_message.fport;
    try std.testing.expectEqual(fport, 0xAB);
    try std.testing.expectEqual(lorawan_message.mac_payload.data_message.frmpayload.len, 25);
    try std.testing.expectEqual(lorawan_message.mic, 0xBDEBD5F0);

    // Encode message
    var encodeBuffer = [_]u8{0} ** 255;
    const encoded = lorawan_message.encode(&encodeBuffer);

    try std.testing.expect(std.mem.eql(u8, encoded, &bytes));
}

test "decode and Encode LoRaWAN JoinRequest message" {
    var join_request_encoded = [_]u8{
        0x00, // MHDR
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, // AppEUI
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, // DevEUI
        0x10, 0x11, // DevNonce
        0x12, 0x13, 0x14, 0x15, // MIC
    };

    // Decoding
    var lorawan_message = try LoRaWAN_Message.decode(&join_request_encoded);
    try std.testing.expect(lorawan_message.mhdr.mtype == .join_request);

    const join_request = switch (lorawan_message.mac_payload) {
        .join_request => |value| value,
        else => unreachable,
    };

    try std.testing.expect(std.mem.eql(u8, &join_request.app_eui, &[_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 }));
    try std.testing.expect(std.mem.eql(u8, &join_request.dev_eui, &[_]u8{ 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F }));
    try std.testing.expect(join_request.dev_nonce == 0x1110);

    // Encoding
    var encode_buffer: [23]u8 = undefined;
    const encoded = lorawan_message.encode(&encode_buffer);
    try std.testing.expect(std.mem.eql(u8, &join_request_encoded, encoded));
}

test "create lorawan unconfirmed_data_up message" {
    const fopts = [_]u8{0} ** 15;
    const frmpayload = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

    // Generate unconfirmedup message
    var lorawan_message = LoRaWAN_Message{
        .mhdr = LoRaWAN_MHDR{
            .mtype = LoRaWAN_MessageType.unconfirmed_data_up,
            .rfu = 0,
            .major = LoRaWAN_MajorVersion.lorawan_r1,
        },
        .mac_payload = LoRaWAN_MACPayload{
            .data_message = LoRaWAN_DataMessage{
                .fhdr = LoRaWAN_FHDR{
                    .dev_addr = 0xFA83B2A1,
                    .fctrl = .{
                        .fctrl_uplink = LoRaWAN_FCtrlUplink{
                            .adr = false,
                            .adr_ack_req = false,
                            .ack = false,
                            .class_b = false,
                            .fopts_len = fopts.len,
                        },
                    },
                    .fcnt = 0x01,
                    .fopts = &fopts,
                },
                .fport = 0x01,
                .frmpayload = &frmpayload,
            },
        },
        .mic = 0x00,
    };

    // encrypt message
    const app_s_key = [16]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 };
    const nwk_s_key = [16]u8{ 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22 };

    try lorawan_message.mac_payload.data_message.encrypt(app_s_key);
    lorawan_message.setMIC(nwk_s_key);

    // Check that frmPayload is encrypted
    try std.testing.expect(!std.mem.eql(u8, lorawan_message.mac_payload.data_message.frmpayload, &frmpayload));

    // decrypt message and check frmPayload and MIC
    var buffer: [255]u8 = undefined;
    try lorawan_message.mac_payload.data_message.getDecryptedPayload(app_s_key, &buffer);

    // Check that frmPayload is decrypted
    try std.testing.expect(std.mem.eql(u8, buffer[0..frmpayload.len], &frmpayload));

    // Check MIC
    try std.testing.expect(lorawan_message.checkMIC(nwk_s_key));
}
