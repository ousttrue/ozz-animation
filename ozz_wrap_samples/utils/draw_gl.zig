const sokol = @import("sokol");
const rowmath = @import("rowmath");
const Mat4 = rowmath.Mat4;

const CameraMatrix = struct { projection: Mat4, view: Mat4 };

const state = struct {
    var depth_test_pip = sokol.gl.Pipeline{};
};

pub fn gl_init() void {
    // a pipeline object with less-equal depth-testing
    state.depth_test_pip = sokol.gl.makePipeline(.{
        .depth = .{
            .write_enabled = true,
            .compare = .LESS_EQUAL,
        },
    });
}

pub fn gl_begin(camera: CameraMatrix) void {
    // sokol.gl.setContext(sokol.gl.defaultContext());
    sokol.gl.defaults();
    sokol.gl.pushPipeline();
    sokol.gl.loadPipeline(state.depth_test_pip);
    sokol.gl.matrixModeProjection();
    sokol.gl.multMatrix(&camera.projection.m[0]);
    sokol.gl.matrixModeModelview();
    sokol.gl.multMatrix(&camera.view.m[0]);
}

pub fn gl_end() void {
    sokol.gl.popPipeline();
}

pub fn gl_draw() void {
    sokol.gl.draw();
    // sokol.gl.contextDraw(sokol.gl.defaultContext());
}

pub fn draw_axis() void {
    sokol.gl.beginLines();
    defer sokol.gl.end();

    // X axis (green).
    sokol.gl.c3f(0xff, 0, 0);
    sokol.gl.v3f(0, 0, 0);
    sokol.gl.v3f(1, 0, 0);

    // Y axis (green).
    sokol.gl.c3f(0, 0xff, 0);
    sokol.gl.v3f(0, 0, 0);
    sokol.gl.v3f(0, 1, 0);

    // Z axis (green).
    sokol.gl.c3f(0, 0, 0xff);
    sokol.gl.v3f(0, 0, 0);
    sokol.gl.v3f(0, 0, 1);
}
