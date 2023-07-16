const std = @import("std");
const Self = @This();

const Mode = enum(u5) {
    old_user = 0x00,
    old_fiq = 0x01,
    old_irq = 0x02,
    old_swi = 0x03,
    user = 0x10,
    fiq = 0x11,
    irq = 0x12,
    svc = 0x13,
    abt = 0x17,
    undef = 0x1b,
    sys = 0x1f,
};

const StatusReg = packed struct(u32) {
    mode: Mode = .user,
    state: enum(u1) { arm, thumb } = .arm,
    fiq_disable: bool = false,
    irq_disable: bool = false,
    abt_disable: bool = false,
    endian: enum(u1) { little, big } = .little,
    _res1: u14 = 0,
    jazelle: bool = false,
    _res0: u2 = 0,
    sticky_overflow: bool = false,
    overflow: bool = false,
    carry: bool = false,
    zero: bool = false,
    sign: bool = false,
};

const SysUserRegStartIdx = 0;
const FiqRegStartIdx = SysUserRegStartIdx + 16;
const SvcRegStartIdx = FiqRegStartIdx + 8;
const AbtRegStartIdx = SvcRegStartIdx + 2;
const IrqRegStartIdx = AbtRegStartIdx + 2;
const UndefRegStartIdx = IrqRegStartIdx + 2;
_registers: [31]u32,
cpsr: StatusReg,
_spsr: [5]StatusReg,

fn getRegRaw(self: *const Self, reg_num: u4) *u32 {
    return switch (self.cpsr.mode) {
        .user => &self.registers[reg_num],
        .fiq => if (reg_num < 8 or reg_num == 15)
            &self.registers[reg_num]
        else
            &self.registers[reg_num - 8 + FiqRegStartIdx],
        .svc => if (reg_num < 13 or reg_num == 15)
            &self.registers[reg_num]
        else
            &self.registers[reg_num - 13 + SvcRegStartIdx],
        .abt => if (reg_num < 13 or reg_num == 15)
            &self.registers[reg_num]
        else
            &self.registers[reg_num - 13 + AbtRegStartIdx],
        .irq => if (reg_num < 13 or reg_num == 15)
            &self.registers[reg_num]
        else
            &self.registers[reg_num - 13 + IrqRegStartIdx],
        .undef => if (reg_num < 13 or reg_num == 15)
            &self.registers[reg_num]
        else
            &self.registers[reg_num - 13 + UndefRegStartIdx],
    };
}

fn setReg(self: *const Self, reg_num: u4, val: u32) u32 {
    getRegRaw(self, reg_num).* = val;
}

fn getReg(self: *const Self, reg_num: u4) u32 {
    return getRegRaw(self, reg_num).*;
}

test "cpsr endianness" {
    var cpsr = StatusReg{};
    try std.testing.expectEqual(@as(u32, 0x00000010), @as(u32, @bitCast(cpsr)));
    cpsr.sign = true;
    try std.testing.expectEqual(@as(u32, 0x80000010), @as(u32, @bitCast(cpsr)));
}

test "banked register idx" {
    try std.testing.expectEqual(30, UndefRegStartIdx);
}

test "static analysis" {
    std.testing.refAllDeclsRecursive(@This());
}
