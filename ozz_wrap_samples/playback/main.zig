//------------------------------------------------------------------------------
//  ozz-anim-sapp.cc
//
//  https://guillaumeblanc.github.io/ozz-animation/
//
//  Port of the ozz-animation "Animation Playback" sample. Use sokol-gl
//  for debug-rendering the animated character skeleton (no skinning).
//------------------------------------------------------------------------------
const std = @import("std");
const c = @cImport({
    @cInclude("stdbool.h");
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
    const loaded = struct {
        var skeleton: ?Skeleton = null;
        var animation = false;
        var failed = false;
    };
    const time = struct {
        var frame: f64 = 0;
        var absolute: f64 = 0;
        var factor: f32 = 0;
        var anim_ratio: f32 = 0;
        var anim_ratio_ui_override = false;
        var paused = false;
    };
};

export fn init() void {
    state.ozz = c.OZZ_init();
    state.time.factor = 1.0;

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
    state.time.frame = sokol.app.frameDuration();

    // update camera
    state.input.screen_width = sokol.app.widthf();
    state.input.screen_height = sokol.app.heightf();
    state.camera.frame(state.input);
    state.input.mouse_wheel = 0;

    sokol.imgui.newFrame(.{
        .width = fb_width,
        .height = fb_height,
        .delta_time = state.time.frame,
        .dpi_scale = sokol.app.dpiScale(),
    });
    draw_ui();

    utils.gl_begin(.{
        .view = state.camera.camera.transform.worldToLocal(),
        .projection = state.camera.camera.projection_matrix,
    });
    utils.draw_axis();
    utils.gl_end();

    {
        sg.beginPass(.{
            .action = state.pass_action,
            .swapchain = sokol.glue.swapchain(),
        });
        defer sg.endPass();

        utils.gl_draw();
        if (state.loaded.animation) {
            if (state.loaded.skeleton) |skeleton| {
                if (!state.time.paused) {
                    state.time.absolute += state.time.frame * state.time.factor;
                }

                // convert current time to animation ration (0.0 .. 1.0)
                const anim_duration = c.OZZ_duration(state.ozz);
                if (!state.time.anim_ratio_ui_override) {
                    state.time.anim_ratio =
                        std.math.mod(
                        f32,
                        @floatCast(state.time.absolute / anim_duration),
                        1.0,
                    ) catch unreachable;
                }
                c.OZZ_eval_animation(state.ozz, state.time.anim_ratio);

                const matrices: [*]const Mat4 = @ptrCast(c.OZZ_model_matrices(state.ozz));
                skeleton.draw(
                    state.camera.viewProjectionMatrix(),
                    matrices,
                );
            }
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

fn draw_ui() void {
    cimgui.igSetNextWindowPos(.{ .x = 20, .y = 20 }, cimgui.ImGuiCond_Once, .{ .x = 0, .y = 0 });
    cimgui.igSetNextWindowSize(.{ .x = 220, .y = 150 }, cimgui.ImGuiCond_Once);
    cimgui.igSetNextWindowBgAlpha(0.35);
    if (cimgui.igBegin("Controls", null, cimgui.ImGuiWindowFlags_NoDecoration |
        cimgui.ImGuiWindowFlags_AlwaysAutoResize))
    {
        if (state.loaded.failed) {
            cimgui.igText("Failed loading character data!");
        } else {
            cimgui.igText("Camera Controls:");
            cimgui.igText("  LMB + Mouse Move: Look");
            cimgui.igText("  Mouse Wheel: Zoom");
            _ = cimgui.igSliderFloat(
                "Distance",
                &state.camera.camera.shift.z,
                0,
                100,
                "%.1f",
                1.0,
            );
            _ = cimgui.igSliderFloat(
                "Latitude",
                &state.camera.camera.yaw,
                -std.math.pi,
                std.math.pi,
                "%.1f",
                1.0,
            );
            _ = cimgui.igSliderFloat(
                "Longitude",
                &state.camera.camera.pitch,
                -std.math.pi,
                std.math.pi,
                "%.1f",
                1.0,
            );
            cimgui.igSeparator();
            cimgui.igText("Time Controls:");
            _ = cimgui.igCheckbox("Paused", &state.time.paused);
            _ = cimgui.igSliderFloat(
                "Factor",
                &state.time.factor,
                0.0,
                10.0,
                "%.1f",
                1.0,
            );
            if (cimgui.igSliderFloat(
                "Ratio",
                &state.time.anim_ratio,
                0.0,
                1.0,
                null,
                0,
            )) {
                state.time.anim_ratio_ui_override = true;
            }
            if (cimgui.igIsItemDeactivatedAfterEdit()) {
                state.time.anim_ratio_ui_override = false;
            }
        }
    }
    cimgui.igEnd();
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
                // std.debug.print("name: {s}\n", .{names[i]});
                skeleton.joints[i] = .{
                    .name = names[i],
                    .parent = if (std.math.maxInt(u16) != parent) parent else null,
                    .is_leaf = c.OZZ_joint_is_leaf(state.ozz, i),
                };
            }
            state.loaded.skeleton = skeleton;
        } else {
            state.loaded.failed = true;
        }
    } else if (response.*.failed) {
        state.loaded.failed = true;
    }
}

export fn animation_data_loaded(response: [*c]const sokol.fetch.Response) void {
    if (response.*.fetched) {
        if (c.OZZ_load_animation(state.ozz, response.*.data.ptr, response.*.data.size)) {
            state.loaded.animation = true;
        } else {
            state.loaded.failed = true;
        }
    } else if (response.*.failed) {
        state.loaded.failed = true;
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
        .window_title = "ozz-anim-sapp.cc",
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = sokol.log.func },
    });
}
