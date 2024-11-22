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

Add this to your `build.zig.zon`:

```zig
.{
    .dependencies = .{
        .lorawan = .{
            .url = "https://github.com/yarreg/zig-lorawan-parser/archive/main.tar.gz",
        },
    },
}
```

## Examples
### Build a UncnfirmedDataUp Message
```zig
const print = @import("std").debug;

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

// Encrypt message
const app_s_key = [16]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 };
const nwk_s_key = [16]u8{ 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22 };

try lorawan_message.mac_payload.data_message.encrypt(app_s_key);
lorawan_message.setMIC(nwk_s_key);

// Encode the LoRaWAN message into the buffer
var buffer = [_]u8{0} ** 255;
const result = lorawan_message.encode(&buffer);

for (result) |byte| {
    print("{x:0<2}", .{byte});
}
```

### Parse UnconfirmedDataUp Message
```zig
const bytes = [_]u8{
    0x40, 0xB4, 0xAA, 0xAA, 0xAA, 0xA0, 0xFA, 0xAE, 0xAB, 0x0B, 0x94, 0x4D,
    0xC0, 0xB6, 0xB1, 0x0B, 0x38, 0x00, 0x38, 0x19, 0x6C, 0x24, 0x37, 0xC2,
    0xFD, 0x74, 0xDC, 0xB9, 0xFD, 0x5B, 0xEE, 0x8D, 0x3C, 0x7F, 0xBD, 0xEB,
    0xD5, 0xF0,
};

var lorawan_message = try LoRaWAN_Message.decode(&bytes);
// ...
```