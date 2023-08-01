const std = @import("std");
const arm = @import("arm.zig");
const utils = @import("utils.zig");
const Field = utils.Field;

pub const Error = error{ Unpredictable, Malformed };

pub const Instruction = union(enum) {
    branch: BranchLinkImmInstruction,
    branch_ex: BranchExRegInstruction,
    swi: SoftwareIntInstruction,
    bkpt: BreakpointInstruction,
};

pub const BranchLinkImmInstruction = struct {
    cond: arm.Cond,
    link: bool,
    offset: i24,

    pub fn parse(op: u32) !BranchLinkImmInstruction {
        const cond = arm.Cond.from(op);
        const link = @as(u1, @truncate(op >> 24)) == 1;
        return .{
            .cond = cond,
            .link = link,
            .offset = @bitCast(@as(u24, @truncate(op))),
        };
    }

    pub fn isExchange(self: BranchLinkImmInstruction) bool {
        return self.cond == .nv;
    }
};

pub const BranchExRegInstruction = struct {
    cond: arm.Cond,
    op: enum(u4) { bx = 0x1, blx = 0x3 },
    rm: u4,

    pub fn parse(op: u32) !BranchExRegInstruction {
        if (@as(u12, @truncate(op >> 8)) != 0b1111_1111_1111)
            return error.Unpredictable
        else if (@as(u24, @truncate(op >> 20)) != 0b0001_0010)
            return error.Malformed;
        const cond = arm.Cond.from(op);
        const opcode = std.meta.intToEnum(Field(BranchExRegInstruction, .op), @as(u4, @truncate(op >> 4))) catch
            return error.Malformed;
        const rm: u4 = @truncate(op);

        return .{
            .cond = cond,
            .op = opcode,
            .rm = rm,
        };
    }

    pub fn isLink(self: BranchExRegInstruction) bool {
        return self.op == .blx;
    }
};

pub const SoftwareIntInstruction = struct {
    cond: arm.Cond,

    fn parse(op: u32) SoftwareIntInstruction {
        const cond = arm.Cond.from(op);

        return SoftwareIntInstruction{ .cond = cond };
    }
};

pub const BreakpointInstruction = struct {
    fn parse(op: u32) BreakpointInstruction {
        const cond = arm.Cond.from(op);
        if (cond != .al) return error.Unpredictable;
        if (@as(u28, @truncate(op)) & 0x120070 != 0x120070) return error.Malformed;

        return BreakpointInstruction{};
    }
};

pub const AluInstruction = struct {
    cond: arm.Cond,
    op: enum { @"and", eor, sub, rsb, add, adc, sbc, rsc, tst, teq, cmp, cmn, orr, mov, bic, mvn },
    s: bool,
    rd: u4,
    rn: u4,
    op2: union(enum) {
        imm: struct {
            ror: u4,
            imm: u8,
        },
        reg: struct {
            shift: union(enum) {
                by_reg: u4,
                by_imm: u5,
            },
            type: arm.ShiftType,
            rm: u4,
        },
    },

    pub fn isLogical(self: AluInstruction) bool {
        return switch (self.op) {
            .@"and", .eor, .tst, .teq, .orr, .mov, .bic, .mvn => true,
            else => false,
        };
    }

    pub fn isArithmetic(self: AluInstruction) bool {
        return switch (self.op) {
            .adc, .add, .cmn, .cmp, .rsb, .rsc, .sbc, .sub => true,
            else => false,
        };
    }

    pub fn parse(op: u32) !AluInstruction {
        const cond = arm.Cond.from(op);
        const imm_second_op = @as(u1, @truncate(op >> 25)) == 1;
        const opcode: Field(AluInstruction, .op) = @enumFromInt(@as(u4, @truncate(op >> 21)));
        const s = @as(u1, @truncate(op >> 20)) == 1;
        const rd: u4 = @truncate(op >> 12);
        const rn: u4 = @truncate(op >> 16);
        const op2_is_imm = @as(u1, @truncate(op >> 4)) == 1;
        const op2_shift_rm = @as(u4, @truncate(op));
        const op2_shift_type: Field(Field(Field(AluInstruction, .op2), .reg), .type) = @enumFromInt(@as(u2, @truncate(op >> 5)));
        const op2_shift_imm = @as(u5, @truncate(op >> 7));
        const op2_shift_reg = @as(u4, @truncate(op >> 8));

        if ((opcode == .mov or opcode == .mvn) and rn != 0) return error.Malformed;

        const op2: Field(AluInstruction, .op2) = if (imm_second_op)
            .{ .imm = .{ .ror = @as(u4, @truncate(op >> 8)), .imm = @as(u8, @truncate(op)) } }
        else
            .{ .reg = .{
                .shift = if (op2_is_imm)
                    .{ .by_reg = op2_shift_reg }
                else
                    .{ .by_imm = op2_shift_imm },
                .type = op2_shift_type,
                .rm = op2_shift_rm,
            } };

        return AluInstruction{
            .cond = cond,
            .op = opcode,
            .s = s,
            .rd = rd,
            .rn = rn,
            .op2 = op2,
        };
    }
};

test "static analysis" {
    std.testing.refAllDeclsRecursive(@This());
}
