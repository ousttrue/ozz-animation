const sokol = @import("sokol");
const rowmath = @import("rowmath");
const Mat4 = rowmath.Mat4;
const Vec3 = rowmath.Vec3;
const RgbaU8 = rowmath.RgbaU8;

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

pub fn draw_grid(_cell_count: i32, _cell_size: f32) void {
    const extent: f32 = @as(f32, @floatFromInt(_cell_count)) * _cell_size;
    const half_extent: f32 = extent * 0.5;
    const corner = Vec3{ .x = -half_extent, .y = 0, .z = -half_extent };

    {
        sokol.gl.beginTriangleStrip();
        defer sokol.gl.end();

        sokol.gl.c4b(0x80, 0xc0, 0xd0, 0xb0);

        var v = corner;
        sokol.gl.v3f(v.x, v.y, v.z);
        v.z = corner.z + extent;
        sokol.gl.v3f(v.x, v.y, v.z);
        v.x = corner.x + extent;
        v.z = corner.z;
        sokol.gl.v3f(v.x, v.y, v.z);
        v.z = corner.z + extent;
        sokol.gl.v3f(v.x, v.y, v.z);
    }

    {
        sokol.gl.beginLines();
        defer sokol.gl.end();

        // Renders lines along X axis.
        var begin = corner;
        sokol.gl.c3b(0x54, 0x55, 0x50);
        var end = begin;
        end.x += extent;
        for (0..@intCast(_cell_count + 1)) |_| {
            sokol.gl.v3f(begin.x, begin.y, begin.z);
            sokol.gl.v3f(end.x, end.y, end.z);
            begin.z += _cell_size;
            end.z += _cell_size;
        }
        // Renders lines along Z axis.
        begin = corner;
        end = begin;
        end.z += extent;
        for (0..@intCast(_cell_count + 1)) |_| {
            sokol.gl.v3f(begin.x, begin.y, begin.z);
            sokol.gl.v3f(end.x, end.y, end.z);
            begin.x += _cell_size;
            end.x += _cell_size;
        }
    }
}

pub const Box = struct {
    min: Vec3,
    max: Vec3,

    pub fn points(self: @This()) struct {
        nnn: Vec3,
        pnn: Vec3,
        ppn: Vec3,
        npn: Vec3,
        nnp: Vec3,
        pnp: Vec3,
        ppp: Vec3,
        npp: Vec3,
    } {
        return .{
            .nnn = .{ .x = self.min.x, .y = self.min.y, .z = self.min.z },
            .pnn = .{ .x = self.max.x, .y = self.min.y, .z = self.min.z },
            .ppn = .{ .x = self.max.x, .y = self.max.y, .z = self.min.z },
            .npn = .{ .x = self.min.x, .y = self.max.y, .z = self.min.z },
            .nnp = .{ .x = self.min.x, .y = self.min.y, .z = self.max.z },
            .pnp = .{ .x = self.max.x, .y = self.min.y, .z = self.max.z },
            .ppp = .{ .x = self.max.x, .y = self.max.y, .z = self.max.z },
            .npp = .{ .x = self.min.x, .y = self.max.y, .z = self.max.z },
        };
    }
};

fn drawLine(v0: Vec3, v1: Vec3) void {
    sokol.gl.v3f(v0.x, v0.y, v0.z);
    sokol.gl.v3f(v1.x, v1.y, v1.z);
}

pub fn drawBox(
    m: Mat4,
    box: Box,
) void {
    const colors = [2]RgbaU8{
        RgbaU8.red,
        RgbaU8.green,
    };
    sokol.gl.pushMatrix();
    defer sokol.gl.popMatrix();
    sokol.gl.multMatrix(&m.m[0]);

    const v = box.points();

    // _ = _box;
    // {
    // Filled boxed
    //   GlImmediatePC im(immediate_renderer(), GL_TRIANGLE_STRIP, _transform);
    //   GlImmediatePC::Vertex v = { {0, 0, 0}, {_colors[0].r, _colors[0].g, _colors[0].b, _colors[0].a}};
    // First 3 cube faces
    //   v.pos[0] = _box.max.x;
    //   v.pos[1] = _box.min.y;
    //   v.pos[2] = _box.min.z;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.min.x;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.max.x;
    //   v.pos[1] = _box.max.y;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.min.x;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.max.x;
    //   v.pos[2] = _box.max.z;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.min.x;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.max.x;
    //   v.pos[1] = _box.min.y;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.min.x;
    //   im.PushVertex(v);
    //   // Link next 3 cube faces with degenerated triangles.
    //   im.PushVertex(v);
    //   v.pos[0] = _box.min.x;
    //   v.pos[1] = _box.max.y;
    //   im.PushVertex(v);
    //   im.PushVertex(v);
    //   // Last 3 cube faces.
    //   v.pos[2] = _box.min.z;
    //   im.PushVertex(v);
    //   v.pos[1] = _box.min.y;
    //   v.pos[2] = _box.max.z;
    //   im.PushVertex(v);
    //   v.pos[2] = _box.min.z;
    //   im.PushVertex(v);
    //   v.pos[0] = _box.max.x;
    //   v.pos[2] = _box.max.z;
    //   im.PushVertex(v);
    //   v.pos[2] = _box.min.z;
    //   im.PushVertex(v);
    //   v.pos[1] = _box.max.y;
    //   v.pos[2] = _box.max.z;
    //   im.PushVertex(v);
    //   v.pos[2] = _box.min.z;
    //   im.PushVertex(v);
    // }

    { // Wireframe boxed
        sokol.gl.beginLines();
        defer sokol.gl.end();

        //   GlImmediatePC im(immediate_renderer(), GL_LINES, _transform);
        //   GlImmediatePC::Vertex v = {
        //       {0, 0, 0}, {_colors[1].r, _colors[1].g, _colors[1].b, _colors[1].a}};
        const c = colors[1];
        sokol.gl.c4b(c.r, c.g, c.b, c.a);
        // First face.
        drawLine(v.nnn, v.npn);
        drawLine(v.npn, v.ppn);
        drawLine(v.ppn, v.pnn);
        drawLine(v.pnn, v.nnn);

        // Second face.
        drawLine(v.nnp, v.npp);
        drawLine(v.npp, v.ppp);
        drawLine(v.ppp, v.pnp);
        drawLine(v.pnp, v.nnp);

        // Link faces.
        drawLine(v.nnp, v.nnn);
        drawLine(v.npp, v.npp);
        drawLine(v.ppp, v.ppn);
        drawLine(v.pnp, v.pnp);
    }
}
