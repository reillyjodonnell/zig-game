const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "the-port",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "the-port",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkSystemLibrary("SDL2"); // Link SDL2 library
    exe.linkSystemLibrary("SDL2_image"); // Link SDL_image library
    exe.linkLibC();

    // Todo understand how to link the dep between sdl and sdl_image
    // if (target.query.isNativeOs() and target.query.os_tag == .linux) {
    //     exe.linkSystemLibrary("SDL2"); // Link SDL2 library
    //     exe.linkSystemLibrary("SDL2_image"); // Link SDL_image library
    //     exe.linkLibC();
    // } else {
    //     const sdl_dep = b.dependency("SDL", .{
    //         .optimize = .ReleaseFast,
    //         .target = target,
    //     });
    //     const sdl_image_dep = b.dependency("SDL_image", .{
    //         .optimize = .ReleaseFast,
    //         .target = target,
    //     });
    //     exe.addIncludePath(sdl_dep.path("include")); // Add SDL2 directory
    //     exe.addIncludePath(sdl_image_dep.path("include"));

    //     exe.linkLibrary(sdl_dep.artifact("SDL2")); // Link SDL2 library
    //     exe.linkLibrary(sdl_image_dep.artifact("SDL2_image")); // Link SDL_image library
    // }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
