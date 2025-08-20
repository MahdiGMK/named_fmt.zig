const std = @import("std");

pub fn writerPrint(writer: *std.io.Writer, comptime fmt: []const u8, args: anytype) !void {
    const Params = @TypeOf(args);
    const params_tinfo = @typeInfo(Params);
    if (params_tinfo != .@"struct") @compileError("Params should be named-struct");

    @setEvalBranchQuota(100000);

    comptime var from: usize = 0;
    inline while (from < fmt.len) {
        comptime var to = from + 1;
        inline while (to < fmt.len and fmt[to] != '{' and fmt[to] != '}') to += 1;
        if (to == fmt.len) {
            try writer.writeAll(fmt[from..to]);
            break;
        }
        if (fmt[from] == '{' and fmt[to] == '}' and to - from < 16) {
            if (@hasField(Params, fmt[from + 1 .. to])) {
                try writer.writeAll(@field(args, fmt[from + 1 .. to]));
                from = to + 1;
                continue;
            }
        }
        try writer.writeAll(fmt[from..to]);
        from = to;
    }
}

pub fn allocPrint(alloc: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![]u8 {
    var buf = std.io.Writer.Allocating.init(alloc);
    try writerPrint(&buf.writer, fmt, args);
    return buf.toOwnedSlice();
}
pub fn allocPrintSentinel(alloc: std.mem.Allocator, comptime sentinel: u8, comptime fmt: []const u8, args: anytype) ![:sentinel]u8 {
    var buf = std.io.Writer.Allocating.init(alloc);
    try writerPrint(&buf.writer, fmt, args);
    return buf.toOwnedSliceSentinel(sentinel);
}

const testing = struct {
    const cases = &.{
        .{
            "salam {x} testing {y}",
            .{ .x = "rand?", .y = "?dnar" },
            "salam rand? testing ?dnar",
        },
        .{
            "salum {xor} testing {yar} random nested : { salam {nest} }",
            .{ .xor = "rand?", .yar = "?dnar", .nest = "nesting" },
            "salum rand? testing ?dnar random nested : { salam nesting }",
        },
        .{
            "{a} }} ,{ {b}, {c}, { {d}, {e}",
            .{ .a = "a", .b = "b", .c = "c", .d = "d", .e = "e" },
            "a }} ,{ b, c, { d, e",
        },
    };
};
test "writerPrint" {
    var buf = std.io.Writer.Allocating.init(std.testing.allocator);
    defer buf.deinit();

    inline for (testing.cases) |c| {
        defer buf.clearRetainingCapacity();
        try writerPrint(&buf.writer, c[0], c[1]);
        try std.testing.expectEqualStrings(c[2], buf.written());
    }
}

test "allocPrint" {
    inline for (testing.cases) |c| {
        const res = try allocPrint(std.testing.allocator, c[0], c[1]);
        defer std.testing.allocator.free(res);

        try std.testing.expectEqualStrings(c[2], res);
    }
}

test "allocPrintSentinel" {
    inline for (testing.cases) |c| {
        const res = try allocPrintSentinel(std.testing.allocator, 0, c[0], c[1]);
        defer std.testing.allocator.free(res);

        try std.testing.expectEqualSentinel(u8, 0, c[2], res);
    }
}
