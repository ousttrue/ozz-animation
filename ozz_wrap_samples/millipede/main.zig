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
const Vec3 = rowmath.Vec3;
const Quat = rowmath.Quat;
const utils = @import("utils");
const Skeleton = utils.Skeleton;

// A millipede slice is 2 legs and a spine.
// Each slice is made of 7 joints, organized as follows.
//          * root
//             |
//           spine                                   spine
//         |       |                                   |
//     left_up    right_up        left_down - left_u - . - right_u - right_down
//       |           |                  |                                    |
//   left_down     right_down     left_foot         * root            right_foot
//     |               |
// left_foot        right_foot

const slice_count_ = 26;

// The following constants are used to define the millipede skeleton and
// animation.
// Skeleton constants.
const kTransUp = Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 };
const kTransDown = Vec3{ .x = 0.0, .y = 0.0, .z = 1.0 };
const kTransFoot = Vec3{ .x = 1.0, .y = 0.0, .z = 0.0 };

const kRotLeftUp =
    Quat.axisAngle(Vec3.up, -std.math.pi / 2.0);
const kRotLeftDown =
    Quat.axisAngle(Vec3.right, std.math.pi / 2.0).mul(Quat.axisAngle(Vec3.up, -std.math.pi / 2.0));
const kRotRightUp =
    Quat.axisAngle(Vec3.up, std.math.pi / 2.0);
const kRotRightDown =
    Quat.axisAngle(Vec3.right, std.math.pi / 2.0).mul(Quat.axisAngle(Vec3.up, -std.math.pi / 2.0));

// Animation constants.
const kDuration: f32 = 6.0;
const kSpinLength: f32 = 0.5;
const kWalkCycleLength: f32 = 2.0;
const kWalkCycleCount = 4;
const kSpinLoop: f32 = 2.0 * kWalkCycleCount * kWalkCycleLength / kSpinLength;

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

    build();
}

fn create_skeleton() void {
    const root_translation = Vec3{ .x = 0.0, .y = 1.0, .z = -slice_count_ * kSpinLength };
    const root_rotation = Quat.identity;
    const root_scale = Vec3.one;

    var root = [1:std.math.maxInt(u16)]u16{
        c.OZZ_raw_skeleton_add_trs(
            state.ozz,
            null,
            "root",
            &root_translation.x,
            &root_rotation.x,
            &root_scale.x,
        )[0],
    };

    var number: [32]u8 = undefined;
    for (0..slice_count_) |i| {
        // Format joint number.
        //   std::snprintf(number, sizeof(number), "%d", i);

        //   root->children.resize(3);

        // Left leg.
        // RawSkeleton::Joint& lu = root->children[0];
        var lu: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "lu{}", .{i}) catch unreachable;
            const translation = kTransUp;
            const rotation = kRotLeftUp;
            const scale = Vec3.one;
            lu = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &root[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        //   lu.children.resize(1);
        //   RawSkeleton::Joint& ld = lu.children[0];
        var ld: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "ld{}", .{i}) catch unreachable;
            const translation = kTransDown;
            const rotation = kRotLeftDown;
            const scale = Vec3.one;
            ld = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &lu[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        //   ld.children.resize(1);
        //   RawSkeleton::Joint& lf = ld.children[0];
        var lf: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "lf{}", .{i}) catch unreachable;
            const translation = Vec3.right;
            const rotation = Quat.identity;
            const scale = Vec3.one;
            lf = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &ld[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        // Right leg.
        //   RawSkeleton::Joint& ru = root->children[1];
        var ru: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "ru{}", .{i}) catch unreachable;
            const translation = kTransUp;
            const rotation = kRotRightUp;
            const scale = Vec3.one;
            ru = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &root[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        //   ru.children.resize(1);
        //   RawSkeleton::Joint& rd = ru.children[0];
        var rd: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "rd{}", .{i}) catch unreachable;
            const translation = kTransDown;
            const rotation = kRotRightDown;
            const scale = Vec3.one;
            rd = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &ru[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        //   rd.children.resize(1);
        //   RawSkeleton::Joint& rf = rd.children[0];
        var rf: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "rf{}", .{i}) catch unreachable;
            const translation = Vec3.right;
            const rotation = Quat.identity;
            const scale = Vec3.one;
            rf = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &rd[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        // Spine.
        //   RawSkeleton::Joint& sp = root->children[2];
        var sp: [*:std.math.maxInt(u16)]const u16 = undefined;
        {
            const name = std.fmt.bufPrintZ(&number, "sp{}", .{i}) catch unreachable;
            const translation = Vec3{ .x = 0.0, .y = 0.0, .z = kSpinLength };
            const rotation = Quat.identity;
            const scale = Vec3.one;
            sp = @ptrCast(c.OZZ_raw_skeleton_add_trs(
                state.ozz,
                &root[0],
                &name[0],
                &translation.x,
                &rotation.x,
                &scale.x,
            ));
        }

        root[0] = sp[0];
    }
}

// Procedurally builds millipede skeleton and walk animation
fn build() void {
    // Initializes the root. The root pointer will change from a spine to the
    // next for each slice.
    create_skeleton();
    // const num_joints = c.OZZ_raw_num_joints(state.ozz);

    // Build the run time skeleton.
    if (!c.OZZ_raw_build(state.ozz)) {
        @panic("OZZ_raw_build");
    }
    const num_joints = c.OZZ_num_joints(state.ozz);
    // std.debug.print("create {}!\n", .{num_joints});
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

    // Build a walk animation.
    // RawAnimation raw_animation;
    // CreateAnimation(&raw_animation);

    // // Build the run time animation from the raw animation.
    // ozz::animation::offline::AnimationBuilder animation_builder;
    // animation_ = animation_builder(raw_animation);
    // if (!animation_) {
    //   return false;
    // }
    //
    // // Allocates runtime buffers.
    // const int num_soa_joints = skeleton_->num_soa_joints();
    // locals_.resize(num_soa_joints);
    // models_.resize(num_joints);
    //
    // // Allocates a context that matches new animation requirements.
    // context_.Resize(num_joints);
    //
    // return true;
}

export fn frame() void {
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
    sg.shutdown();

    c.OZZ_shutdown(state.ozz);
    state.ozz = null;
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
        .window_title = "ozz_wrap_millipede",
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = sokol.log.func },
    });
}
