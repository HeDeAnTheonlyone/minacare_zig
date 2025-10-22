const std = @import("std");
const map_converter = @import("tool/map_converter.zig");

pub fn build(b: *std.Build) !void {
    const emit_asm = b.option(
        bool,
        "emit-asm",
        "Additionally creates an assembly file next to the executable."
    ) orelse false;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    try map_converter.start();

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "minaland",
        .root_module = exe_mod,
    });

    const raylib_deb = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib_artifact = raylib_deb.artifact("raylib");
    const raylib = raylib_deb.module("raylib");
    const raygui = raylib_deb.module("raygui");

    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    if (emit_asm) {
        const install_asm = b.addInstallBinFile(exe.getEmittedAsm(), "minaland.asm");
        b.getInstallStep().dependOn(&install_asm.step);
    }

    b.installArtifact(exe);

    const docs = b.addObject(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        })
    });

    docs.root_module.linkLibrary(raylib_artifact);
    docs.root_module.addImport("raylib", raylib);
    docs.root_module.addImport("raygui", raygui);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&install_docs.step);

    const run_cmd = b.addRunArtifact(exe); //INFO create run cmd
    const run_step = b.step("run", "Runs the executable."); //INFO create run step (the argument for the command line)
    run_step.dependOn(&run_cmd.step); //INFO make the cmd step depend on the the actual run cmd
}
