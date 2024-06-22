const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn processInput(window: *const glfw.Window) void {
    if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
        window.setShouldClose(true);
    }
}

var gl_procs: gl.ProcTable = undefined;

// zig fmt: off
const vertices = [_]f32{
    -0.5, -0.5, -0.0,
    0.5, -0.5, 0.0,
    0.0, 0.5, 0.0,
};

const indices = []u32 {
    0, 1, 3,
    1, 2, 3,
};
// zig fmt: on

const vertex_shader_src: []const u8 =
    \\ #version 410 core
    \\ layout (location = 0) in vec3 aPos;
    \\
    \\ void main()
    \\ {
    \\  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\ }
;

const fragment_shader_src: []const u8 =
    \\ #version 410 core
    \\ out vec4 FragColor;
    \\
    \\ void main()
    \\ {
    \\  FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\ }
;

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    const window = glfw.Window.create(640, 480, "Helloooo", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // enables VSync, to avoid unnecessary drawing
    glfw.swapInterval(1);

    if (!gl_procs.init(glfw.getProcAddress)) {
        std.log.err("failed to load OpenGL functions: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
    if (vertex_shader == 0) {
        std.log.err("failed to create vertex shader", .{});
        std.process.exit(1);
    }
    defer gl.DeleteShader(vertex_shader);

    gl.ShaderSource(
        vertex_shader,
        1,
        (&vertex_shader_src.ptr)[0..1],
        (&@as(c_int, @intCast(vertex_shader_src.len)))[0..1],
    );
    gl.CompileShader(vertex_shader);

    var success: c_int = undefined;
    var info_log_buf: [512]u8 = undefined;

    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(vertex_shader, info_log_buf.len, null, &info_log_buf);
        std.log.err("failed to compile vertex shader: {s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        std.process.exit(1);
    }

    const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
    if (fragment_shader == 0) {
        std.log.err("failed to create fragment shader", .{});
        std.process.exit(1);
    }
    defer gl.DeleteShader(fragment_shader);

    gl.ShaderSource(
        fragment_shader,
        1,
        (&fragment_shader_src.ptr)[0..1],
        (&@as(c_int, @intCast(fragment_shader_src.len)))[0..1],
    );
    gl.CompileShader(fragment_shader);

    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(fragment_shader, info_log_buf.len, null, &info_log_buf);
        std.log.err("failed to compile fragment shader: {s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        std.process.exit(1);
    }

    const program = gl.CreateProgram();
    if (program == 0) {
        std.log.err("failed to create program", .{});
        std.process.exit(1);
    }
    errdefer gl.DeleteProgram(program);

    gl.AttachShader(program, vertex_shader);
    gl.AttachShader(program, fragment_shader);
    gl.LinkProgram(program);

    gl.GetProgramiv(program, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(program, info_log_buf.len, null, &info_log_buf);
        std.log.err("failed to link program: {s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        std.process.exit(1);
    }
    defer gl.DeleteProgram(program);

    while (!window.shouldClose()) {
        glfw.pollEvents();
        processInput(&window);

        gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.UseProgram(program);
        defer gl.UseProgram(0);

        const framebuffer_size = window.getFramebufferSize();
        gl.Viewport(0, 0, @intCast(framebuffer_size.width), @intCast(framebuffer_size.height));

        window.swapBuffers();
    }
}
