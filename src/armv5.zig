const std = @import("std");
const arm = @import("arm.zig");
const utils = @import("utils.zig");
const Field = utils.Field;

pub const Error = error{ Unpredictable, Malformed };

pub const Instruction = union(enum) {
    branch: BranchLinkImmInstruction,
    branch_ex: BranchExRegInstruction,
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

test "static analysis" {
    std.testing.refAllDeclsRecursive(@This());
}
