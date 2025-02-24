const std = @import("std");
const builtin = @import("builtin");

const cpp_sources = &[_][]const u8{
    "imgui.cpp",
    "imgui_demo.cpp",
    "imgui_draw.cpp",
    "imgui_tables.cpp",
    "imgui_widgets.cpp",
};

const include_dirs = &[_][]const u8{
    ".",
};

pub const Backend = enum {
    OSX,
    SDL2,
    SDL3,
    Vulkan,
    Metal,
    WGPU,
    Win32,
    OpenGL3,
    OpenGL2,
    GLUT,
    GLFW,
    DX9,
    DX12,
    DX11,
    DX10,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const backend = b.option(Backend, "backend", "What rendering backend to use for IMGUI") orelse Backend.SDL2;

    const build_lib = b.option(bool, "build_lib", "Whether to try and build a static library by linking to system executables.") orelse false;

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    var lib = b.addStaticLibrary(.{
        .name = "imgui",
        .optimize = mode,
        .target = target,
    });

    b.getInstallStep().dependOn(&b.addInstallHeaderFile(b.path("imgui.h"), "imgui.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile(b.path("imgui_internal.h"), "imgui_internal.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile(b.path("imstb_rectpack.h"), "imstb_rectpack.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile(b.path("imstb_textedit.h"), "imstb_textedit.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile(b.path("imstb_truetype.h"), "imstb_truetype.h").step);

    const BackendFiles = struct {
        sources: []const []const u8,
        // if not specified, assumed that you want sources names but with .h
        headers: ?[]const []const u8 = null,
    };

    const backend_files: BackendFiles = switch (backend) {
        .OSX => BackendFiles{ .sources = &.{"backends/imgui_impl_osx.mm"}, .headers = &.{"backends/imgui_impl_osx.h"} },
        .SDL2 => BackendFiles{ .sources = &.{
            "backends/imgui_impl_sdl2",
            "backends/imgui_impl_sdlrenderer2",
        } },
        .SDL3 => BackendFiles{ .sources = &.{
            "backends/imgui_impl_sdl3",
            "backends/imgui_impl_sdlrenderer3",
        } },
        .Vulkan => BackendFiles{ .sources = &.{"backends/imgui_impl_vulkan"} },
        .WGPU => BackendFiles{ .sources = &.{"backends/imgui_impl_wgpu"} },
        .Win32 => BackendFiles{ .sources = &.{"backends/imgui_impl_win32"} },
        .OpenGL3 => BackendFiles{
            .sources = &.{"backends/imgui_impl_opengl3.cpp"},
            .headers = &.{
                "backends/imgui_impl_opengl3.h",
                "backends/imgui_impl_opengl3_loader.h",
            },
        },
        .OpenGL2 => BackendFiles{ .sources = &.{"backends/imgui_impl_opengl2"} },
        .Metal => BackendFiles{
            .sources = &.{"backends/imgui_impl_metal.mm"},
            .headers = &.{"backends/imgui_impl_metal.h"},
        },
        .GLUT => BackendFiles{ .sources = &.{"backends/imgui_impl_glut"} },
        .GLFW => BackendFiles{ .sources = &.{"backends/imgui_impl_glfw"} },
        .DX9 => BackendFiles{ .sources = &.{"backends/imgui_impl_dx9"} },
        .DX10 => BackendFiles{ .sources = &.{"backends/imgui_impl_dx10"} },
        .DX11 => BackendFiles{ .sources = &.{"backends/imgui_impl_dx11"} },
        .DX12 => BackendFiles{ .sources = &.{"backends/imgui_impl_dx12"} },
    };

    if (backend_files.headers != null) {
        for (backend_files.headers.?) |header| {
            b.getInstallStep().dependOn(
                &b.addInstallHeaderFile(b.path(header), std.fs.path.basename(header)).step,
            );
        }
    }

    var sources = std.ArrayList([]const u8).init(b.allocator);
    defer sources.deinit();

    for (backend_files.sources) |source_file| {
        const ext = std.fs.path.extension(source_file);
        if (ext.len != 0) {
            try sources.append(source_file);
        } else {
            try sources.append(b.fmt("{s}.cpp", .{source_file}));
        }
    }

    // install sources so that downstream can handle building if desired
    for (sources.items) |filename| {
        const output = b.pathJoin(&.{ "src", std.fs.path.basename(filename) });
        b.installFile(filename, output);
    }

    lib.addIncludePath(b.path("."));

    if (build_lib) {
        switch (backend) {
            .SDL2 => lib.linkSystemLibrary("SDL2"),
            .SDL3 => lib.linkSystemLibrary("SDL3"),
            .OSX => lib.linkFramework("Cocoa"),
            .Vulkan => lib.linkSystemLibrary("vulkan"),
            .GLFW => lib.linkSystemLibrary("glfw"),
            .GLUT => lib.linkSystemLibrary("glut"),
            .Win32 => lib.linkSystemLibrary("win32"),
            .OpenGL3 => lib.linkSystemLibrary("opengl3"),
            .OpenGL2 => lib.linkSystemLibrary("opengl2"),
            else => @panic("Unsupported platform for building imgui with system libs"),
        }

        b.installArtifact(lib);
    }

    lib.linkLibCpp();

    for (include_dirs) |include_dir| {
        try flags.append(b.fmt("-I{s}", .{include_dir}));
    }

    {
        const flags_owned = flags.toOwnedSlice() catch @panic("OOM");
        lib.addCSourceFiles(.{
            .files = sources.toOwnedSlice() catch @panic("OOM"),
            .flags = flags_owned,
        });
    }
}
