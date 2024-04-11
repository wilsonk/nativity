const std = @import("std");
const Allocator = std.mem.Allocator;

const TestError = error{
    junk_in_test_directory,
    abnormal_exit_code,
    signaled,
    stopped,
    unknown,
    fail,
};

fn collectDirectoryDirEntries(allocator: Allocator, path: []const u8) ![]const []const u8 {
    var dir = try std.fs.cwd().openDir(path, .{
        .iterate = true,
    });
    var dir_iterator = dir.iterate();
    var dir_entries = std.ArrayListUnmanaged([]const u8){};

    while (try dir_iterator.next()) |entry| {
        switch (entry.kind) {
            .directory => try dir_entries.append(allocator, try allocator.dupe(u8, entry.name)),
            else => return error.junk_in_test_directory,
        }
    }

    dir.close();

    return dir_entries.items;
}

const bootstrap_relative_path = "zig-out/bin/nat";

fn runStandalone(allocator: Allocator, args: struct {
    directory_path: []const u8,
    group_name: []const u8,
    self_hosted: bool,
    is_test: bool,
}) !void {
    const test_names = try collectDirectoryDirEntries(allocator, args.directory_path);

    const total_compilation_count = test_names.len;
    var ran_compilation_count: usize = 0;
    var failed_compilation_count: usize = 0;

    var ran_test_count: usize = 0;
    var failed_test_count: usize = 0;
    const total_test_count = test_names.len;

    std.debug.print("\n[{s} START]\n\n", .{args.group_name});

    for (test_names) |test_name| {
        std.debug.print("{s}... ", .{test_name});
        const source_file_path = try std.mem.concat(allocator, u8, &.{ args.directory_path, "/", test_name, "/main.nat" });
        const compile_run = try std.ChildProcess.run(.{
            .allocator = allocator,
            // TODO: delete -main_source_file?
            .argv = &.{ if (args.self_hosted) self_hosted_relative_path else bootstrap_relative_path, if (args.is_test) "test" else "exe", "-main_source_file", source_file_path },
            .max_output_bytes = std.math.maxInt(u64),
        });
        ran_compilation_count += 1;

        const compilation_result: TestError!bool = switch (compile_run.term) {
            .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
            .Signal => error.signaled,
            .Stopped => error.stopped,
            .Unknown => error.unknown,
        };

        const compilation_success = compilation_result catch b: {
            failed_compilation_count += 1;
            break :b false;
        };

        std.debug.print("[COMPILATION {s}] ", .{if (compilation_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
        if (compile_run.stdout.len > 0) {
            std.debug.print("STDOUT:\n\n{s}\n\n", .{compile_run.stdout});
        }
        if (compile_run.stderr.len > 0) {
            std.debug.print("STDERR:\n\n{s}\n\n", .{compile_run.stderr});
        }

        if (compilation_success and !args.self_hosted) {
            const test_path = try std.mem.concat(allocator, u8, &.{ "nat/", test_name });
            const test_run = try std.ChildProcess.run(.{
                .allocator = allocator,
                // TODO: delete -main_source_file?
                .argv = &.{test_path},
                .max_output_bytes = std.math.maxInt(u64),
            });
            ran_test_count += 1;
            const test_result: TestError!bool = switch (test_run.term) {
                .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
                .Signal => error.signaled,
                .Stopped => error.stopped,
                .Unknown => error.unknown,
            };

            const test_success = test_result catch b: {
                failed_test_count += 1;
                break :b false;
            };
            std.debug.print("[TEST {s}]\n", .{if (test_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
            if (test_run.stdout.len > 0) {
                std.debug.print("STDOUT:\n\n{s}\n\n", .{test_run.stdout});
            }
            if (test_run.stderr.len > 0) {
                std.debug.print("STDERR:\n\n{s}\n\n", .{test_run.stderr});
            }
        } else {
            std.debug.print("\n", .{});
        }
    }

    std.debug.print("\n{s} COMPILATIONS: {}. FAILED: {}\n", .{ args.group_name, total_compilation_count, failed_compilation_count });
    std.debug.print("{s} TESTS: {}. RAN: {}. FAILED: {}\n", .{ args.group_name, total_test_count, ran_test_count, failed_test_count });

    if (failed_compilation_count > 0 or failed_test_count > 0) {
        return error.fail;
    }
}

fn runStandaloneTests(allocator: Allocator, args: struct {
    self_hosted: bool,
}) !void {
    const standalone_test_dir_path = "test/standalone";
    const standalone_test_names = try collectDirectoryDirEntries(allocator, standalone_test_dir_path);

    const total_compilation_count = standalone_test_names.len;
    var ran_compilation_count: usize = 0;
    var failed_compilation_count: usize = 0;

    var ran_test_count: usize = 0;
    var failed_test_count: usize = 0;
    const total_test_count = standalone_test_names.len;

    for (standalone_test_names) |standalone_test_name| {
        std.debug.print("{s}... ", .{standalone_test_name});
        const source_file_path = try std.mem.concat(allocator, u8, &.{ standalone_test_dir_path, "/", standalone_test_name, "/main.nat" });
        const compile_run = try std.ChildProcess.run(.{
            .allocator = allocator,
            // TODO: delete -main_source_file?
            .argv = &.{ if (args.self_hosted) self_hosted_relative_path else bootstrap_relative_path, "exe", "-main_source_file", source_file_path },
            .max_output_bytes = std.math.maxInt(u64),
        });
        ran_compilation_count += 1;

        const compilation_result: TestError!bool = switch (compile_run.term) {
            .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
            .Signal => error.signaled,
            .Stopped => error.stopped,
            .Unknown => error.unknown,
        };

        const compilation_success = compilation_result catch b: {
            failed_compilation_count += 1;
            break :b false;
        };

        std.debug.print("[COMPILATION {s}] ", .{if (compilation_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
        if (compile_run.stdout.len > 0) {
            std.debug.print("STDOUT:\n\n{s}\n\n", .{compile_run.stdout});
        }
        if (compile_run.stderr.len > 0) {
            std.debug.print("STDERR:\n\n{s}\n\n", .{compile_run.stderr});
        }

        if (compilation_success and !args.self_hosted) {
            const test_path = try std.mem.concat(allocator, u8, &.{ "nat/", standalone_test_name });
            const test_run = try std.ChildProcess.run(.{
                .allocator = allocator,
                // TODO: delete -main_source_file?
                .argv = &.{test_path},
                .max_output_bytes = std.math.maxInt(u64),
            });
            ran_test_count += 1;
            const test_result: TestError!bool = switch (test_run.term) {
                .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
                .Signal => error.signaled,
                .Stopped => error.stopped,
                .Unknown => error.unknown,
            };

            const test_success = test_result catch b: {
                failed_test_count += 1;
                break :b false;
            };
            std.debug.print("[TEST {s}]\n", .{if (test_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
            if (test_run.stdout.len > 0) {
                std.debug.print("STDOUT:\n\n{s}\n\n", .{test_run.stdout});
            }
            if (test_run.stderr.len > 0) {
                std.debug.print("STDERR:\n\n{s}\n\n", .{test_run.stderr});
            }
        } else {
            std.debug.print("\n", .{});
        }
    }

    std.debug.print("\nTOTAL COMPILATIONS: {}. FAILED: {}\n", .{ total_compilation_count, failed_compilation_count });
    std.debug.print("TOTAL TESTS: {}. RAN: {}. FAILED: {}\n", .{ total_test_count, ran_test_count, failed_test_count });

    if (failed_compilation_count > 0 or failed_test_count > 0) {
        return error.fail;
    }
}

fn runBuildTests(allocator: Allocator, args: struct {
    self_hosted: bool,
}) !void {
    std.debug.print("\n[BUILD TESTS]\n\n", .{});
    const previous_cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    const test_dir_path = "test/build";
    const test_names = try collectDirectoryDirEntries(allocator, test_dir_path);
    const test_dir_realpath = try std.fs.cwd().realpathAlloc(allocator, test_dir_path);
    const compiler_realpath = try std.fs.cwd().realpathAlloc(allocator, if (args.self_hosted) self_hosted_relative_path else bootstrap_relative_path);
    try std.posix.chdir(test_dir_realpath);

    const total_compilation_count = test_names.len;
    var ran_compilation_count: usize = 0;
    var failed_compilation_count: usize = 0;

    var ran_test_count: usize = 0;
    var failed_test_count: usize = 0;
    const total_test_count = test_names.len;

    for (test_names) |test_name| {
        std.debug.print("{s}... ", .{test_name});
        try std.posix.chdir(test_name);

        const compile_run = try std.ChildProcess.run(.{
            .allocator = allocator,
            // TODO: delete -main_source_file?
            .argv = &.{ compiler_realpath, "build" },
            .max_output_bytes = std.math.maxInt(u64),
        });

        ran_compilation_count += 1;

        const compilation_result: TestError!bool = switch (compile_run.term) {
            .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
            .Signal => error.signaled,
            .Stopped => error.stopped,
            .Unknown => error.unknown,
        };

        const compilation_success = compilation_result catch b: {
            failed_compilation_count += 1;
            break :b false;
        };

        std.debug.print("[COMPILATION {s}] ", .{if (compilation_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
        if (compile_run.stdout.len > 0) {
            std.debug.print("STDOUT:\n\n{s}\n\n", .{compile_run.stdout});
        }
        if (compile_run.stderr.len > 0) {
            std.debug.print("STDERR:\n\n{s}\n\n", .{compile_run.stderr});
        }

        if (compilation_success and !args.self_hosted) {
            const test_path = try std.mem.concat(allocator, u8, &.{ "nat/", test_name });
            const test_run = try std.ChildProcess.run(.{
                .allocator = allocator,
                // TODO: delete -main_source_file?
                .argv = &.{test_path},
                .max_output_bytes = std.math.maxInt(u64),
            });
            ran_test_count += 1;
            const test_result: TestError!bool = switch (test_run.term) {
                .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
                .Signal => error.signaled,
                .Stopped => error.stopped,
                .Unknown => error.unknown,
            };

            const test_success = test_result catch b: {
                failed_test_count += 1;
                break :b false;
            };
            std.debug.print("[TEST {s}]\n", .{if (test_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
            if (test_run.stdout.len > 0) {
                std.debug.print("STDOUT:\n\n{s}\n\n", .{test_run.stdout});
            }
            if (test_run.stderr.len > 0) {
                std.debug.print("STDERR:\n\n{s}\n\n", .{test_run.stderr});
            }
        } else {
            std.debug.print("\n", .{});
        }

        try std.posix.chdir(test_dir_realpath);
    }

    std.debug.print("\nTOTAL COMPILATIONS: {}. FAILED: {}\n", .{ total_compilation_count, failed_compilation_count });
    std.debug.print("TOTAL TESTS: {}. RAN: {}. FAILED: {}\n", .{ total_test_count, ran_test_count, failed_test_count });

    try std.posix.chdir(previous_cwd);

    if (failed_compilation_count > 0 or failed_test_count > 0) {
        return error.fail;
    }
}

fn runStdTests(allocator: Allocator, args: struct {
    self_hosted: bool,
}) !void {
    var errors = false;
    std.debug.print("std... ", .{});

    const result = try std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = &.{ if (args.self_hosted) self_hosted_relative_path else bootstrap_relative_path, "test", "-main_source_file", "lib/std/std.nat", "-name", "std" },
        .max_output_bytes = std.math.maxInt(u64),
    });
    const compilation_result: TestError!bool = switch (result.term) {
        .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
        .Signal => error.signaled,
        .Stopped => error.stopped,
        .Unknown => error.unknown,
    };

    const compilation_success = compilation_result catch b: {
        errors = true;
        break :b false;
    };

    std.debug.print("[COMPILATION {s}] ", .{if (compilation_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
    if (result.stdout.len > 0) {
        std.debug.print("STDOUT:\n\n{s}\n\n", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        std.debug.print("STDERR:\n\n{s}\n\n", .{result.stderr});
    }

    if (compilation_success and !args.self_hosted) {
        const test_run = try std.ChildProcess.run(.{
            .allocator = allocator,
            // TODO: delete -main_source_file?
            .argv = &.{"nat/std"},
            .max_output_bytes = std.math.maxInt(u64),
        });
        const test_result: TestError!bool = switch (test_run.term) {
            .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
            .Signal => error.signaled,
            .Stopped => error.stopped,
            .Unknown => error.unknown,
        };

        const test_success = test_result catch b: {
            errors = true;
            break :b false;
        };
        std.debug.print("[TEST {s}]\n", .{if (test_success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
        if (test_run.stdout.len > 0) {
            std.debug.print("STDOUT:\n\n{s}\n\n", .{test_run.stdout});
        }
        if (test_run.stderr.len > 0) {
            std.debug.print("STDERR:\n\n{s}\n\n", .{test_run.stderr});
        }
    }

    if (errors) return error.fail;
}

fn runCmakeTests(allocator: Allocator, dir_path: []const u8) !void {
    var errors = false;
    const original_dir = try std.fs.cwd().realpathAlloc(allocator, ".");
    const cc_dir = try std.fs.cwd().openDir(dir_path, .{
        .iterate = true,
    });

    const cc_dir_path = try cc_dir.realpathAlloc(allocator, ".");
    try std.posix.chdir(cc_dir_path);

    var cc_dir_iterator = cc_dir.iterate();
    while (try cc_dir_iterator.next()) |cc_entry| {
        switch (cc_entry.kind) {
            .directory => {
                std.debug.print("{s}...\n", .{cc_entry.name});
                try std.posix.chdir(cc_entry.name);
                try std.fs.cwd().deleteTree("build");
                try std.fs.cwd().makeDir("build");
                try std.posix.chdir("build");

                const cmake = try std.ChildProcess.run(.{
                    .allocator = allocator,
                    // TODO: delete -main_source_file?
                    .argv = &.{
                        "cmake",
                        "..",
                        // "--debug-trycompile",
                        // "--debug-output",
                        // "-G", "Unix Makefiles",
                        // "-DCMAKE_VERBOSE_MAKEFILE=On",
                        try std.mem.concat(allocator, u8, &.{ "-DCMAKE_C_COMPILER=", "nat;cc" }),
                        try std.mem.concat(allocator, u8, &.{ "-DCMAKE_CXX_COMPILER=", "nat;c++" }),
                        try std.mem.concat(allocator, u8, &.{ "-DCMAKE_ASM_COMPILER=", "nat;cc" }),
                    },
                    .max_output_bytes = std.math.maxInt(u64),
                });
                const cmake_result: TestError!bool = switch (cmake.term) {
                    .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
                    .Signal => error.signaled,
                    .Stopped => error.stopped,
                    .Unknown => error.unknown,
                };

                const cmake_success = cmake_result catch b: {
                    errors = true;
                    break :b false;
                };

                if (cmake.stdout.len > 0) {
                    std.debug.print("STDOUT:\n\n{s}\n\n", .{cmake.stdout});
                }
                if (cmake.stderr.len > 0) {
                    std.debug.print("STDERR:\n\n{s}\n\n", .{cmake.stderr});
                }

                var success = cmake_success;
                if (success) {
                    const ninja = try std.ChildProcess.run(.{
                        .allocator = allocator,
                        // TODO: delete -main_source_file?
                        .argv = &.{"ninja"},
                        .max_output_bytes = std.math.maxInt(u64),
                    });
                    const ninja_result: TestError!bool = switch (ninja.term) {
                        .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
                        .Signal => error.signaled,
                        .Stopped => error.stopped,
                        .Unknown => error.unknown,
                    };

                    const ninja_success = ninja_result catch b: {
                        errors = true;
                        break :b false;
                    };

                    if (!ninja_success) {
                        if (ninja.stdout.len > 0) {
                            std.debug.print("STDOUT:\n\n{s}\n\n", .{ninja.stdout});
                        }
                        if (ninja.stderr.len > 0) {
                            std.debug.print("STDERR:\n\n{s}\n\n", .{ninja.stderr});
                        }
                    }

                    success = success and ninja_success;

                    if (success) {
                        const run = try std.ChildProcess.run(.{
                            .allocator = allocator,
                            // TODO: delete -main_source_file?
                            .argv = &.{
                                try std.mem.concat(allocator, u8, &.{ "./", cc_entry.name }),
                            },
                            .max_output_bytes = std.math.maxInt(u64),
                        });
                        const run_result: TestError!bool = switch (run.term) {
                            .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
                            .Signal => error.signaled,
                            .Stopped => error.stopped,
                            .Unknown => error.unknown,
                        };

                        const run_success = run_result catch b: {
                            errors = true;
                            break :b false;
                        };

                        if (run.stdout.len > 0) {
                            std.debug.print("STDOUT:\n\n{s}\n\n", .{run.stdout});
                        }
                        if (run.stderr.len > 0) {
                            std.debug.print("STDERR:\n\n{s}\n\n", .{run.stderr});
                        }

                        success = success and run_success;
                    }
                }

                std.debug.print("[TEST {s}]\n", .{if (success) "\x1b[32mOK\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
            },
            else => std.debug.panic("Entry {s} is a {s}", .{ cc_entry.name, @tagName(cc_entry.kind) }),
        }

        try std.posix.chdir(cc_dir_path);
    }

    try std.posix.chdir(original_dir);

    if (errors) {
        return error.fail;
    }
}

const self_hosted_exe_name = "compiler";
const self_hosted_relative_path = "nat/" ++ self_hosted_exe_name;

fn compile_self_hosted(allocator: Allocator, args: struct {
    is_test: bool,
}) !void {
    const compile_run = try std.ChildProcess.run(.{
        .allocator = allocator,
        // TODO: delete -main_source_file?
        .argv = &.{ bootstrap_relative_path, if (args.is_test) "test" else "exe", "-main_source_file", "src/main.nat", "-name", self_hosted_exe_name },
        .max_output_bytes = std.math.maxInt(u64),
    });

    const compilation_result: TestError!bool = switch (compile_run.term) {
        .Exited => |exit_code| if (exit_code == 0) true else error.abnormal_exit_code,
        .Signal => error.signaled,
        .Stopped => error.stopped,
        .Unknown => error.unknown,
    };



    _ = compilation_result catch |err| {
        std.debug.print("Compiling the self-hosted compiler failed!\n", .{});
        if (compile_run.stdout.len > 0) {
            std.debug.print("{s}\n", .{compile_run.stdout});
        }
        if (compile_run.stderr.len > 0) {
            std.debug.print("{s}\n", .{compile_run.stderr});
        }
        return err;
    };
}

fn run_test_suite(allocator: Allocator, args: struct {
    self_hosted: bool,
}) bool {
    const self_hosted = args.self_hosted;
    std.debug.print("TESTING {s} COMPILER...\n=================\n", .{if (self_hosted) "SELF-HOSTED" else "BOOTSTRAP"});
    var errors = false;
    runStandalone(allocator, .{
        .directory_path = "test/standalone",
        .group_name = "STANDALONE",
        .is_test = false,
        .self_hosted = self_hosted,
    }) catch {
        errors = true;
    };
    runBuildTests(allocator, .{
        .self_hosted = self_hosted,
    }) catch {
        errors = true;
    };
    runStandalone(allocator, .{
        .directory_path = "test/tests",
        .group_name = "TEST EXECUTABLE",
        .is_test = true,
        .self_hosted = self_hosted,
    }) catch {
        errors = true;
    };
    //
    runStdTests(allocator, .{
        .self_hosted = self_hosted,
    }) catch {
        errors = true;
    };

    if (!self_hosted) {
        runCmakeTests(allocator, "test/cc") catch {
            errors = true;
        };
        runCmakeTests(allocator, "test/c++") catch {
            errors = true;
        };

        switch (@import("builtin").os.tag) {
            .macos => {},
            .windows => {},
            .linux => switch (@import("builtin").abi) {
                .gnu => runCmakeTests(allocator, "test/cc_linux") catch {
                    errors = true;
                },
                .musl => {},
                else => @compileError("ABI not supported"),
            },
            else => @compileError("OS not supported"),
        }
    }

    return errors;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var errors = run_test_suite(allocator, .{
        .self_hosted = false,
    });

    if (!errors) {
        if (compile_self_hosted(allocator, .{
            .is_test = false,
        })) |_| {
            errors = errors or run_test_suite(allocator, .{
                .self_hosted = true,
            });
        } else |err| {
            err catch {};
            errors = true;
        }
    }

    if (errors) {
        return error.fail;
    }
}
