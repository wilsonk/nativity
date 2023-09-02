const std = @import("std");

fn addCompiler(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode, comptime simd: bool) *std.Build.CompileStep {
    const suffix = if (simd) "" else "_scalar";

    const exe = b.addExecutable(.{
        .name = "compiler" ++ suffix,
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.strip = false;

    const options = b.addOptions();
    options.addOption(bool, "simd", simd);
    exe.addOptions("options", options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run" ++ suffix, "Run the app");
    run_step.dependOn(&run_cmd.step);

    const disassembly_cmd = b.addSystemCommand(&.{ "objdump", "-M", "intel", "-dxS" });
    disassembly_cmd.addArtifactArg(exe);

    const disassembly_step = b.step("dis" ++ suffix, "Disassembly the application");
    disassembly_step.dependOn(&disassembly_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    unit_tests.addOptions("options", options);
    unit_tests.strip = false;

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test" ++ suffix, "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    return exe;
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const simd = addCompiler(b, target, optimize, true);
    _ = simd;
    const scalar = addCompiler(b, target, optimize, false);
    _ = scalar;
}
