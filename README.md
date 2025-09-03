# zig-lorawan-parser

A pure Zig implementation of a LoRaWAN packet parser and encoder. This library is intended to be used in LoRaWAN network servers and gateways to parse and encode LoRaWAN packets. Additionally, it can be used for analytics purposes to monitor and analyze LoRaWAN network traffic.

## Features

- Parse and encode LoRaWAN packets
- Support for Join Request/Accept messages
- Support for Unconfirmed/Confirmed Data Up/Down messages
- MAC commands parsing and encoding
- Payload encryption/decryption using AES-128
- Message Integrity Code (MIC) calculation and verification
- Zero dependencies (uses only Zig standard library)
- Zero allocations (uses only stack memory) suitable for embedded systems

## Usage

### Adding to Your Project

#### Execute the following command to add the library to `build.zig.zon`:
```bash
zig fetch --save git+https://github.com/yarreg/zig-lorawan-parser.git
```
#### Add following lines to your `build.zig` file:
```zig
const lorawan = b.dependency("lorawan", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("lorawan", lorawan.module("lorawan"));
```


## Examples
### Build a UncnfirmedDataUp Message
```zig
const print = @import("std").debug.print;
const lorawan = @import("lorawan").lorawan;

pub fn main() !void {
    const fopts = [_]u8{0} ** 15;
    const frmpayload = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

    // Generate unconfirmedup message
    var lorawan_message = lorawan.LoRaWAN_Message{
        .mhdr = lorawan.LoRaWAN_MHDR{
            .mtype = lorawan.LoRaWAN_MessageType.unconfirmed_data_up,
            .rfu = 0,
            .major = lorawan.LoRaWAN_MajorVersion.lorawan_r1,
        },
        .mac_payload = lorawan.LoRaWAN_MACPayload{
            .data_message = lorawan.LoRaWAN_DataMessage{
                .fhdr = lorawan.LoRaWAN_FHDR{
                    .dev_addr = 0xFA83B2A1,
                    .fctrl = .{
                        .fctrl_uplink = lorawan.LoRaWAN_FCtrlUplink{
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

    // Encrypt message
    const app_s_key = [16]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 };
    const nwk_s_key = [16]u8{ 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22 };

    try lorawan_message.mac_payload.data_message.encrypt(app_s_key);
    lorawan_message.setMIC(nwk_s_key);

    // Encode the LoRaWAN message into the buffer
    var buffer = [_]u8{0} ** 255;
    const result = lorawan_message.encode(&buffer);

    for (result) |byte| {
        print("{X:0>2}", .{byte});
    }
    print("\n", .{});
}
```

### Parse UnconfirmedDataUp Message
```zig
const print = @import("std").debug.print;
const lorawan = @import("lorawan").lorawan;

pub fn main() !void {
    const app_s_key = [16]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 };
    const nwk_s_key = [16]u8{ 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22 };

    const bytes = [_]u8{
        0x40, 0xB4, 0xAA, 0xAA, 0xAA, 0xA0, 0xFA, 0xAE, 0xAB, 0x0B, 0x94, 0x4D,
        0xC0, 0xB6, 0xB1, 0x0B, 0x38, 0x00, 0x38, 0x19, 0x6C, 0x24, 0x37, 0xC2,
        0xFD, 0x74, 0xDC, 0xB9, 0xFD, 0x5B, 0xEE, 0x8D, 0x3C, 0x7F, 0xBD, 0xEB,
        0xD5, 0xF0,
    };

    var lorawan_message = try lorawan.LoRaWAN_Message.decode(&bytes);
    print("dev_addr: {X}\n", .{lorawan_message.mac_payload.data_message.fhdr.dev_addr});

    // verify mic
    if (!lorawan_message.checkMIC(nwk_s_key)) {
        print("MIC verification failed\n", .{});
    }

    // decrypt
    var buffer = [_]u8{0} ** 255;
    const decrypted_payload = try lorawan_message.mac_payload.data_message.getDecryptedPayload(app_s_key, &buffer);
    print("decrypted payload: {any}\n", .{decrypted_payload});
}
```

# ZIG
Tested with Zig 0.15.1