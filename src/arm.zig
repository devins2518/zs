pub const Cond = enum(u4) {
    eq = 0x0,
    ne,
    cs,
    cc,
    mi,
    pl,
    vs,
    vc,
    hi,
    ls,
    ge,
    lt,
    gt,
    le,
    al,
    nv,

    pub fn from(op: u32) Cond {
        return @enumFromInt(@as(u4, @truncate(op >> 28)));
    }
};
