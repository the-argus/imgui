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
    "src/",
};

pub const Backend = enum {
    OSX,
    SDL2,
    SDL3,
    Vulkan,
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

pub fn getSources(b: *std.Build, backend: Backend) []const []const u8 {
    var sources = std.ArrayList([]const u8).init(b.allocator);
    defer sources.deinit();
    sources.appendSlice(cpp_sources) catch @panic("OOM");

    const slice: []const u8 = switch (backend) {
        .OSX => &.{"backends/imgui_impl_osx.mm"},
        .SDL2 => &.{
            "backends/imgui_impl_sdlrenderer2.cpp",
            "backends/imgui_impl_sdl2.cpp",
        },
        .SDL3 => &.{
            "backends/imgui_impl_sdlrenderer3.cpp",
            "backends/imgui_impl_sdl3.cpp",
        },
        .Vulkan => &.{"backends/imgui_impl_vulkan.cpp"},
        .WGPU => &.{"backends/imgui_impl_wpgu.cpp"},
        .Win32 => &.{"backends/imgui_impl_win32.cpp"},
        .OpenGL3 => &.{"backends/imgui_impl/opengl3.cpp"},
        .OpenGL2 => &.{"backends/imgui_impl/opengl2.cpp"},
        .GLUT => &.{"backends/imgui_impl_glut.cpp"},
        .GLFW => &.{"backends/imgui_impl_glfw.cpp"},
        .DX9 => &.{"backends/imgui_impl_dx9.cpp"},
        .DX10 => &.{"backends/imgui_impl_dx10.cpp"},
        .DX11 => &.{"backends/imgui_impl_dx11.cpp"},
        .DX12 => &.{"backends/imgui_impl_dx12.cpp"},
    };

    sources.appendSlice(slice) catch @panic("OOM");

    return sources.toOwnedSlice() catch @panic("OOM");
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const backend = b.option(Backend, "backend", "What rendering backend to use for IMGUI") orelse Backend.SDL2;

    const build_lib = b.option(bool, "build_lib", "Whether to try and build a static library by linking to system executables.") orelse false;

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    var lib: *std.Build.CompileStep =
        b.addStaticLibrary(.{
        .name = "imgui",
        .optimize = mode,
        .target = target,
    });

    const sources: []const []const u8 = getSources(b, backend);
    for (sources) |file| {
        const output = b.pathJoin(&.{ "src", std.fs.path.basename(file) });
        b.installFile(file, output);
    }

    b.getInstallStep().dependOn(&b.addInstallHeaderFile("imgui.h", "imgui.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile("imgui_internal.h", "imgui_internal.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile("imstb_rectpack.h", "imstb_rectpack.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile("imstb_textedit.h", "imstb_textedit.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile("imstb_trutype.h", "imstb_trutype.h").step);
    b.getInstallStep().dependOn(&b.addInstallHeaderFile("imstb_trutype.h", "imstb_trutype.h").step);
    const headers: []const u8 = switch (backend) {
        .OSX => &.{"backends/imgui_impl_osx.h"},
        .SDL2 => &.{
            "backends/imgui_impl_sdl2",
            "backends/imgui_impl_sdlrenderer2.h",
        },
        .SDL3 => &.{
            "backends/imgui_impl_sdl3",
            "backends/imgui_impl_sdlrenderer3.h",
        },
        .Vulkan => &.{"imgui_impl_vulkan.h"},
        .WGPU => &.{"backends/imgui_impl_wpgu.h"},
        .Win32 => &.{"backends/imgui_impl_win32.h"},
        .OpenGL3 => &.{"backends/imgui_impl/opengl3.h"},
        .OpenGL2 => &.{"backends/imgui_impl/opengl2.h"},
        .GLUT => &.{"backends/imgui_impl_glut.h"},
        .GLFW => &.{"backends/imgui_impl_glfw.h"},
        .DX9 => &.{"backends/imgui_impl_dx9.h"},
        .DX10 => &.{"backends/imgui_impl_dx10.h"},
        .DX11 => &.{"backends/imgui_impl_dx11.h"},
        .DX12 => &.{"backends/imgui_impl_dx12.h"},
    };

    for (headers) |header| {
        b.getInstallStep().dependOn(&b.addInstallHeaderFile(header, std.fs.path.basename(header)).step);
    }

    lib.addIncludePath(.{ .path = "." });

    if (build_lib) {
        switch (backend) {
            .SDL2 => lib.linkSystemLibrary("SDL2"),
            .SDL3 => lib.linkSystemLibrary("SDL3"),
            .OSX => lib.linkFramework("Cocoa"),
            .Vulkan => lib.linkLibrary("vulkan"),
            .GLFW => lib.linkLibrary("glfw"),
            .GLUT => lib.linkLibrary("glut"),
            .Win32 => lib.linkLibrary("win32"),
            .OpenGL3 => lib.linkLibrary("opengl3"),
            .OpenGL2 => lib.linkLibrary("opengl2"),
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
        lib.addCSourceFiles(getSources(b, backend), flags_owned);
    }
}
