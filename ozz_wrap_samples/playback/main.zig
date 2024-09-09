const std = @import("std");
const c = @cImport({
    @cInclude("ozz_wrap.h");
});
const sokol = @import("sokol");
const sg = sokol.gfx;
const cimgui = @import("cimgui");
const rowmath = @import("rowmath");
const InputState = rowmath.InputState;
const MouseCamera = rowmath.MouseCamera;
const Mat4 = rowmath.Mat4;
const utils = @import("utils");
const Skeleton = utils.Skeleton;

var skel_data_buffer: [4 * 1024]u8 = undefined;
var anim_data_buffer: [32 * 1024]u8 = undefined;

const state = struct {
    var input: InputState = .{};
    var camera: MouseCamera = .{};
    var ozz: ?*c.ozz_t = null;
    var pass_action = sg.PassAction{};
    var ozz_state = utils.State{};
};

export fn init() void {
    state.ozz = c.OZZ_init();
    state.ozz_state.time.factor = 1.0;

    // setup sokol-gfx
    sg.setup(.{
        .environment = sokol.glue.environment(),
        .logger = .{ .func = sokol.log.func },
    });
    sokol.gl.setup(.{
        .sample_count = sokol.app.sampleCount(),
        .logger = .{ .func = sokol.log.func },
    });
    utils.gl_init();

    // setup sokol-imgui
    sokol.imgui.setup(.{ .logger = .{ .func = sokol.log.func } });

    // initialize pass action for default-pass
    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.1, .b = 0.2, .a = 1.0 },
    };

    state.camera.init();

    // setup sokol-fetch
    sokol.fetch.setup(.{
        .max_requests = 2,
        .num_channels = 1,
        .num_lanes = 2,
        .logger = .{ .func = sokol.log.func },
    });

    // start loading the skeleton and animation files
    _ = sokol.fetch.send(.{
        .path = "media/bin/pab_skeleton.ozz",
        .callback = skeleton_data_loaded,
        .buffer = sokol.fetch.asRange(&skel_data_buffer),
    });

    _ = sokol.fetch.send(.{
        .path = "media/bin/pab_crossarms.ozz",
        .callback = animation_data_loaded,
        .buffer = sokol.fetch.asRange(&anim_data_buffer),
    });
}

export fn frame() void {
    sokol.fetch.dowork();

    const fb_width = sokol.app.width();
    const fb_height = sokol.app.height();
    state.ozz_state.time.frame = sokol.app.frameDuration();

    // update camera
    state.input.screen_width = sokol.app.widthf();
    state.input.screen_height = sokol.app.heightf();
    state.camera.frame(state.input);
    state.input.mouse_wheel = 0;

    // draw ui
    sokol.imgui.newFrame(.{
        .width = fb_width,
        .height = fb_height,
        .delta_time = state.ozz_state.time.frame,
        .dpi_scale = sokol.app.dpiScale(),
    });
    utils.draw_ui(&state.ozz_state, &state.camera.camera);

    // draw axis & grid
    utils.gl_begin(.{
        .view = state.camera.camera.transform.worldToLocal(),
        .projection = state.camera.camera.projection_matrix,
    });
    utils.draw_axis();
    utils.draw_grid(20, 1.0);
    utils.gl_end();

    // render
    {
        sg.beginPass(.{
            .action = state.pass_action,
            .swapchain = sokol.glue.swapchain(),
        });
        defer sg.endPass();

        utils.gl_draw();
        if (state.ozz_state.loaded.skeleton) |skeleton| {
            if (state.ozz_state.loaded.animation) {
                const anim_ratio = state.ozz_state.update(c.OZZ_duration(state.ozz));
                // const anim_duration = ;
                c.OZZ_eval_animation(state.ozz, anim_ratio);
            }

            const matrices: [*]const Mat4 = @ptrCast(c.OZZ_model_matrices(state.ozz));
            skeleton.draw(
                state.camera.viewProjectionMatrix(),
                matrices,
            );
        }

        sokol.imgui.render();
    }
    sg.commit();
}

export fn input(e: [*c]const sokol.app.Event) void {
    if (sokol.imgui.handleEvent(e.*)) {
        return;
    }
    utils.handle_camera_input(e, &state.input);
}

export fn cleanup() void {
    sokol.imgui.shutdown();
    sokol.gl.shutdown();
    sokol.fetch.shutdown();
    sg.shutdown();

    c.OZZ_shutdown(state.ozz);
    state.ozz = null;
}

export fn skeleton_data_loaded(response: [*c]const sokol.fetch.Response) void {
    if (response.*.fetched) {
        if (c.OZZ_load_skeleton(state.ozz, response.*.data.ptr, response.*.data.size)) {
            const num_joints = c.OZZ_num_joints(state.ozz);
            var skeleton = Skeleton.init(std.heap.page_allocator, num_joints) catch unreachable;
            const parents = c.OZZ_joint_parents(state.ozz);
            const names: [*]const [*:0]const u8 = @ptrCast(c.OZZ_joint_names(state.ozz));
            for (0..num_joints) |i| {
                const parent: u16 = parents[i];
                skeleton.joints[i] = .{
                    .name = names[i],
                    .parent = if (std.math.maxInt(u16) != parent) parent else null,
                    .is_leaf = c.OZZ_joint_is_leaf(state.ozz, i),
                };
            }
            state.ozz_state.loaded.skeleton = skeleton;
        } else {
            state.ozz_state.loaded.failed = true;
        }
    } else if (response.*.failed) {
        state.ozz_state.loaded.failed = true;
    }
}

export fn animation_data_loaded(response: [*c]const sokol.fetch.Response) void {
    if (response.*.fetched) {
        if (c.OZZ_load_animation(state.ozz, response.*.data.ptr, response.*.data.size)) {
            state.ozz_state.loaded.animation = true;
        } else {
            state.ozz_state.loaded.failed = true;
        }
    } else if (response.*.failed) {
        state.ozz_state.loaded.failed = true;
    }
}

pub fn main() void {
    sokol.app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = 800,
        .height = 600,
        .sample_count = 4,
        .window_title = "ozz_wrap_playback",
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = sokol.log.func },
    });
}
