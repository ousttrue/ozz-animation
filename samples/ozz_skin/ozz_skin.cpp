#define SOKOL_IMPL
#define SOKOL_GLCORE
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_time.h"
#include "sokol_log.h"
#include "sokol_glue.h"

#define SOKOL_GL_IMPL
#include "util/sokol_gl.h"

#include "imgui.h"
#define SOKOL_IMGUI_IMPL
#include "util/sokol_imgui.h"
#define SOKOL_GFX_IMGUI_IMPL
#include "util/sokol_gfx_imgui.h"

#define HANDMADE_MATH_IMPLEMENTATION
#define HANDMADE_MATH_NO_SSE
#include "HandmadeMath.h"
#include "camera.h"

#include "ozz_skin.glsl.h"

// ozz-animation headers
#include "ozz/animation/runtime/animation.h"
#include "ozz/animation/runtime/skeleton.h"
#include "ozz/animation/runtime/sampling_job.h"
#include "ozz/animation/runtime/local_to_model_job.h"
#include "ozz/base/io/stream.h"
#include "ozz/base/io/archive.h"
#include "ozz/base/containers/vector.h"
#include "ozz/base/maths/soa_transform.h"
#include "ozz/base/maths/vec_float.h"
#include "framework/mesh.h"

#include <memory>   // std::unique_ptr, std::make_unique
#include <cmath>    // fmodf
#include <string>

// the upper limit for joint palette size is 256 (because the mesh joint indices
// are stored in packed byte-size vertex formats), but the example mesh only needs less than 64
#define MAX_PALETTE_JOINTS (64)

// this defines the size of the instance-buffer and height of the joint-texture
#define MAX_INSTANCES (512)

// wrapper struct for managed ozz-animation C++ objects, must be deleted
// before shutdown, otherwise ozz-animation will report a memory leak
typedef struct {
    ozz::animation::Skeleton skeleton;
    ozz::animation::Animation animation;
    ozz::vector<uint16_t> joint_remaps;
    ozz::vector<ozz::math::Float4x4> mesh_inverse_bindposes;
    ozz::vector<ozz::math::SoaTransform> local_matrices;
    ozz::vector<ozz::math::Float4x4> model_matrices;
    ozz::animation::SamplingJob::Context cache;
} ozz_t;

// a skinned-mesh vertex, we don't need the texcoords and tangent
// in our example renderer so we just drop them. Normals, joint indices
// and joint weights are packed into BYTE4N and UBYTE4N
//
// NOTE: joint indices are packed as UBYTE4N and not UBYTE4 because of
// D3D11 compatibility (see "A NOTE ON PORTABLE PACKED VERTEX FORMATS" in sokol_gfx.h)
typedef struct {
    float position[3];
    uint32_t normal;
    uint32_t joint_indices;
    uint32_t joint_weights;
} vertex_t;

// per-instance data for hardware-instanced rendering includes the
// transposed 4x3 model-to-world matrix, and information where the
// joint palette is found in the joint texture
typedef struct {
    float xxxx[4];
    float yyyy[4];
    float zzzz[4];
    float joint_uv[2];
} instance_t;

static struct {
    std::unique_ptr<ozz_t> ozz;
    sg_pass_action pass_action;
    sg_pipeline pip;
    sg_image joint_texture;
    sg_sampler smp;
    sg_bindings bind;
    int num_instances;          // current number of character instances
    int num_triangle_indices;
    int num_skeleton_joints;    // number of joints in the skeleton
    int num_skin_joints;        // number of joints actually used by skinned mesh
    int joint_texture_width;    // in number of pixels
    int joint_texture_height;   // in number of pixels
    int joint_texture_pitch;    // in number of floats
    camera_t camera;
    bool draw_enabled;
    struct {
        bool skeleton;
        bool animation;
        bool mesh;
        bool failed;
    } loaded;
    struct {
        double frame_time_ms;
        double frame_time_sec;
        double abs_time_sec;
        uint64_t anim_eval_time;
        float factor;
        bool paused;
    } time;
    struct {
        sgimgui_t sgimgui;
        bool joint_texture_shown;
        int joint_texture_scale;
        simgui_image_t joint_texture;
    } ui;
    bool debug_draw_skel;
    int debug_draw_index;
} state;

// instance data buffer;
static instance_t instance_data[MAX_INSTANCES];

// joint-matrix upload buffer, each joint consists of transposed 4x3 matrix
static float joint_upload_buffer[MAX_INSTANCES][MAX_PALETTE_JOINTS][3][4];

static void init_instance_data(void);
static void draw_ui(void);
static void skel_data_loaded(const std::string& filename);
static void anim_data_loaded(const std::string& filename);
static void mesh_data_loaded(const std::string& filename);

static void eval_animation(int debug_draw_idx);
static void draw_skeleton(int debug_draw_idx);

static void init(void) {
    state.ozz = std::make_unique<ozz_t>();
    state.num_instances = 1;
    state.draw_enabled = true;
    state.time.factor = 1.0f;
    state.ui.joint_texture_scale = 4;

    // setup sokol-gfx
    sg_desc sgdesc = { };
    sgdesc.environment = sglue_environment();
    sgdesc.logger.func = slog_func;
    sg_setup(&sgdesc);

    // setup sokol-gl
    sgl_desc_t sgldesc = { };
    sgldesc.sample_count = sapp_sample_count();
    sgldesc.logger.func = slog_func;
    sgl_setup(&sgldesc);

    // setup sokol-time
    stm_setup();

    // setup sokol-imgui
    simgui_desc_t imdesc = { };
    imdesc.logger.func = slog_func;
    simgui_setup(&imdesc);
    sgimgui_desc_t sgimgui_desc = { };
    sgimgui_init(&state.ui.sgimgui, &sgimgui_desc);

    // initialize pass action for default-pass
    state.pass_action.colors[0].load_action = SG_LOADACTION_CLEAR;
    state.pass_action.colors[0].clear_value = { 0.0f, 0.0f, 0.0f, 1.0f };

    // initialize camera controller
    camera_desc_t camdesc = { };
    camdesc.min_dist = 2.0f;
    camdesc.max_dist = 40.0f;
    camdesc.center.Y = 1.1f;
    camdesc.distance = 3.0f;
    camdesc.latitude = 20.0f;
    camdesc.longitude = 20.0f;
    cam_init(&state.camera, &camdesc);

    // vertex-skinning shader and pipeline object for 3d rendering, note
    // the hardware-instanced vertex layout
    sg_pipeline_desc pip_desc = { };
    pip_desc.shader = sg_make_shader(skinned_shader_desc(sg_query_backend()));
    pip_desc.layout.buffers[0].stride = sizeof(vertex_t);
    pip_desc.layout.buffers[1].stride = sizeof(instance_t);
    pip_desc.layout.buffers[1].step_func = SG_VERTEXSTEP_PER_INSTANCE;
    pip_desc.layout.attrs[ATTR_vs_position].format = SG_VERTEXFORMAT_FLOAT3;
    pip_desc.layout.attrs[ATTR_vs_normal].format = SG_VERTEXFORMAT_BYTE4N;
    pip_desc.layout.attrs[ATTR_vs_jindices].format = SG_VERTEXFORMAT_UBYTE4N;
    pip_desc.layout.attrs[ATTR_vs_jweights].format = SG_VERTEXFORMAT_UBYTE4N;
    pip_desc.layout.attrs[ATTR_vs_inst_xxxx].format = SG_VERTEXFORMAT_FLOAT4;
    pip_desc.layout.attrs[ATTR_vs_inst_xxxx].buffer_index = 1;
    pip_desc.layout.attrs[ATTR_vs_inst_yyyy].format = SG_VERTEXFORMAT_FLOAT4;
    pip_desc.layout.attrs[ATTR_vs_inst_yyyy].buffer_index = 1;
    pip_desc.layout.attrs[ATTR_vs_inst_zzzz].format = SG_VERTEXFORMAT_FLOAT4;
    pip_desc.layout.attrs[ATTR_vs_inst_zzzz].buffer_index = 1;
    pip_desc.layout.attrs[ATTR_vs_inst_joint_uv].format = SG_VERTEXFORMAT_FLOAT2;
    pip_desc.layout.attrs[ATTR_vs_inst_joint_uv].buffer_index = 1;
    pip_desc.index_type = SG_INDEXTYPE_UINT16;
    // ozz mesh data appears to have counter-clock-wise face winding
    pip_desc.face_winding = SG_FACEWINDING_CCW;
    pip_desc.cull_mode = SG_CULLMODE_BACK;
    pip_desc.depth.write_enabled = true;
    pip_desc.depth.compare = SG_COMPAREFUNC_LESS_EQUAL;
    state.pip = sg_make_pipeline(&pip_desc);

    // create a dynamic joint-palette texture and sampler
    state.joint_texture_width = MAX_PALETTE_JOINTS * 3;
    state.joint_texture_height = MAX_INSTANCES;
    state.joint_texture_pitch = state.joint_texture_width * 4;
    sg_image_desc img_desc = { };
    img_desc.width = state.joint_texture_width;
    img_desc.height = state.joint_texture_height;
    img_desc.num_mipmaps = 1;
    img_desc.pixel_format = SG_PIXELFORMAT_RGBA32F;
    img_desc.usage = SG_USAGE_STREAM;
    state.joint_texture = sg_make_image(&img_desc);
    state.bind.vs.images[SLOT_joint_tex] = state.joint_texture;

    sg_sampler_desc smp_desc = { };
    smp_desc.min_filter = SG_FILTER_NEAREST;
    smp_desc.mag_filter = SG_FILTER_NEAREST;
    smp_desc.wrap_u = SG_WRAP_CLAMP_TO_EDGE;
    smp_desc.wrap_v = SG_WRAP_CLAMP_TO_EDGE;
    state.smp = sg_make_sampler(&smp_desc);
    state.bind.vs.samplers[SLOT_smp] = state.smp;

    // create an sokol-imgui wrapper for the joint texture
    simgui_image_desc_t simgui_img_desc = { };
    simgui_img_desc.image = state.joint_texture;
    simgui_img_desc.sampler = state.smp;
    state.ui.joint_texture = simgui_make_image(&simgui_img_desc);

    // create a static instance-data buffer, in this demo, character instances
    // don't move around and also are not clipped against the view volume,
    // so we can just initialize a static instance data buffer upfront
    init_instance_data();
    sg_buffer_desc buf_desc = { };
    buf_desc.type = SG_BUFFERTYPE_VERTEXBUFFER;
    buf_desc.data = SG_RANGE(instance_data);
    state.bind.vertex_buffers[1] = sg_make_buffer(&buf_desc);

    // start loading data
    {
        skel_data_loaded("media/bin/pab_skeleton.ozz");
    }
    {
        anim_data_loaded("media/bin/pab_crossarms.ozz");
    }
    {
        mesh_data_loaded("media/bin/arnaud_mesh_4.ozz");
    }
}

// initialize the static instance data, since the character instances don't
// move around or are clipped against the view volume in this demo, the instance
// data is initialized once and lives in an immutable instance buffer
static void init_instance_data(void) {
    assert((state.joint_texture_width > 0) && (state.joint_texture_height > 0));

    // initialize the character instance model-to-world matrices
    for (int i=0, x=0, y=0, dx=0, dy=0; i < MAX_INSTANCES; i++, x+=dx, y+=dy) {
        instance_t* inst = &instance_data[i];

        // a 3x4 transposed model-to-world matrix (only the x/z position is set)
        inst->xxxx[0]=1.0f; inst->xxxx[1]=0.0f; inst->xxxx[2]=0.0f; inst->xxxx[3] = (float)x * 1.5f;
        inst->yyyy[0]=0.0f; inst->yyyy[1]=1.0f; inst->yyyy[2]=0.0f; inst->yyyy[3] = 0.0f;
        inst->zzzz[0]=0.0f; inst->zzzz[1]=0.0f; inst->zzzz[2]=1.0f; inst->zzzz[3] = (float)y * 1.5f;

        // at a corner?
        if (abs(x) == abs(y)) {
            if (x >= 0) {
                // top-right corner: start a new ring
                if (y >= 0) { x+=1; y+=1; dx=0; dy=-1; }
                // bottom-right corner
                else { dx=-1; dy=0; }
            }
            else {
                // top-left corner
                if (y >= 0) { dx=+1; dy=0; }
                // bottom-left corner
                else { dx=0; dy=+1; }
            }
        }
    }

    // the skin_info vertex component contains information about where to find
    // the joint palette for this character instance in the joint texture
    const float half_pixel_x = 0.5f / (float)state.joint_texture_width;
    const float half_pixel_y = 0.5f / (float)state.joint_texture_height;
    for (int i = 0; i < MAX_INSTANCES; i++) {
        instance_t* inst = &instance_data[i];
        inst->joint_uv[0] = half_pixel_x;
        inst->joint_uv[1] = half_pixel_y + (i / (float)state.joint_texture_height);
    }
}

// compute skinning matrices, and upload into joint texture
static void update_joint_texture(void) {

    uint64_t start_time = stm_now();
    const float anim_duration = state.ozz->animation.duration();
    for (int instance = 0; instance < state.num_instances; instance++) {

        // each character instance evaluates its own animation
        const float anim_ratio = fmodf(((float)state.time.abs_time_sec + (instance*0.1f)) / anim_duration, 1.0f);

        // sample animation
        // NOTE: using one cache per instance versus one cache per animation
        // makes a small difference, but not much
        ozz::animation::SamplingJob sampling_job;
        sampling_job.animation = &state.ozz->animation;
        sampling_job.context = &state.ozz->cache;
        sampling_job.ratio = anim_ratio;
        sampling_job.output = make_span(state.ozz->local_matrices);
        sampling_job.Run();

        // convert joint matrices from local to model space
        ozz::animation::LocalToModelJob ltm_job;
        ltm_job.skeleton = &state.ozz->skeleton;
        ltm_job.input = make_span(state.ozz->local_matrices);
        ltm_job.output = make_span(state.ozz->model_matrices);
        ltm_job.Run();

        // compute skinning matrices and write to joint texture upload buffer
        for (int i = 0; i < state.num_skin_joints; i++) {
            ozz::math::Float4x4 skin_matrix = state.ozz->model_matrices[state.ozz->joint_remaps[i]] * state.ozz->mesh_inverse_bindposes[i];
            const ozz::math::SimdFloat4& c0 = skin_matrix.cols[0];
            const ozz::math::SimdFloat4& c1 = skin_matrix.cols[1];
            const ozz::math::SimdFloat4& c2 = skin_matrix.cols[2];
            const ozz::math::SimdFloat4& c3 = skin_matrix.cols[3];

            float* ptr = &joint_upload_buffer[instance][i][0][0];
            *ptr++ = ozz::math::GetX(c0); *ptr++ = ozz::math::GetX(c1); *ptr++ = ozz::math::GetX(c2); *ptr++ = ozz::math::GetX(c3);
            *ptr++ = ozz::math::GetY(c0); *ptr++ = ozz::math::GetY(c1); *ptr++ = ozz::math::GetY(c2); *ptr++ = ozz::math::GetY(c3);
            *ptr++ = ozz::math::GetZ(c0); *ptr++ = ozz::math::GetZ(c1); *ptr++ = ozz::math::GetZ(c2); *ptr++ = ozz::math::GetZ(c3);
        }
    }
    state.time.anim_eval_time = stm_since(start_time);

    sg_image_data img_data = { };
    // FIXME: upload partial texture? (needs sokol-gfx fixes)
    img_data.subimage[0][0] = SG_RANGE(joint_upload_buffer);
    sg_update_image(state.joint_texture, img_data);
}

static void frame(void) {
    const int fb_width = sapp_width();
    const int fb_height = sapp_height();
    state.time.frame_time_sec = sapp_frame_duration();
    state.time.frame_time_ms = sapp_frame_duration() * 1000.0;
    cam_update(&state.camera, fb_width, fb_height);

    simgui_new_frame({ fb_width, fb_height, state.time.frame_time_sec, sapp_dpi_scale() });
    draw_ui();

    sg_pass pass = {};
    pass.action = state.pass_action;
    pass.swapchain = sglue_swapchain();
    sg_begin_pass(&pass);
    if (state.loaded.animation && state.loaded.skeleton && state.loaded.mesh) {
        if (!state.time.paused) {
            state.time.abs_time_sec += state.time.frame_time_sec * state.time.factor;
        }
        update_joint_texture();

        vs_params_t vs_params = { };
        vs_params.view_proj = state.camera.view_proj;
        vs_params.joint_pixel_width = 1.0f / (float)state.joint_texture_width;
        sg_apply_pipeline(state.pip);
        sg_apply_bindings(&state.bind);
        sg_apply_uniforms(SG_SHADERSTAGE_VS, SLOT_vs_params, SG_RANGE_REF(vs_params));
        if (state.draw_enabled) {
            sg_draw(0, state.num_triangle_indices, state.num_instances);
        }

        if (state.debug_draw_skel) {
            eval_animation(state.debug_draw_index);
            draw_skeleton(state.debug_draw_index);
            sgl_draw();
        }
    }
    simgui_render();
    sg_end_pass();
    sg_commit();
}

static void input(const sapp_event* ev) {
    if (simgui_handle_event(ev)) {
        return;
    }
    cam_handle_event(&state.camera, ev);
}

static void cleanup(void) {
    sgimgui_discard(&state.ui.sgimgui);
    simgui_shutdown();
    sgl_shutdown();
    sg_shutdown();

    // free C++ objects early, otherwise ozz-animation complains about memory leaks
    state.ozz = nullptr;
}

static void eval_animation(int debug_draw_idx) {
    // convert current time to animation ration (0.0 .. 1.0)
    const float anim_duration = state.ozz->animation.duration();
    const int instance = debug_draw_idx;
    const float anim_ratio = fmodf(((float)state.time.abs_time_sec + (instance*0.1f)) / anim_duration, 1.0f);

    // sample animation
    ozz::animation::SamplingJob sampling_job;
    sampling_job.animation = &state.ozz->animation;
    sampling_job.context = &state.ozz->cache;
    sampling_job.ratio = anim_ratio;
    sampling_job.output = make_span(state.ozz->local_matrices);
    sampling_job.Run();

    // convert joint matrices from local to model space
    ozz::animation::LocalToModelJob ltm_job;
    ltm_job.skeleton = &state.ozz->skeleton;
    ltm_job.input = make_span(state.ozz->local_matrices);
    ltm_job.output = make_span(state.ozz->model_matrices);
    ltm_job.Run();
}

static void draw_vec(const ozz::math::SimdFloat4& vec) {
    sgl_v3f(ozz::math::GetX(vec), ozz::math::GetY(vec), ozz::math::GetZ(vec));
}

static void draw_line(const ozz::math::SimdFloat4& v0, const ozz::math::SimdFloat4& v1) {
    draw_vec(v0);
    draw_vec(v1);
}

// this draws a wireframe 3d rhombus between the current and parent joints
static void draw_joint(int joint_index, int parent_joint_index, ozz::math::SimdFloat4 global_offset = {0, 0, 0, 0}) {
    if (parent_joint_index < 0) {
        return;
    }

    using namespace ozz::math;

    const Float4x4& m0 = state.ozz->model_matrices[joint_index];
    const Float4x4& m1 = state.ozz->model_matrices[parent_joint_index];

    const SimdFloat4 p0 = m0.cols[3] + global_offset;
    const SimdFloat4 p1 = m1.cols[3] + global_offset;
    const SimdFloat4 ny = m1.cols[1];
    const SimdFloat4 nz = m1.cols[2];

    const SimdFloat4 len = SplatX(Length3(p1 - p0)) * simd_float4::Load1(0.1f);

    const SimdFloat4 pmid = p0 + (p1 - p0) * simd_float4::Load1(0.66f);
    const SimdFloat4 p2 = pmid + ny * len;
    const SimdFloat4 p3 = pmid + nz * len;
    const SimdFloat4 p4 = pmid - ny * len;
    const SimdFloat4 p5 = pmid - nz * len;

    sgl_c3f(1.0f, 1.0f, 0.0f);
    draw_line(p0, p2); draw_line(p0, p3); draw_line(p0, p4); draw_line(p0, p5);
    draw_line(p1, p2); draw_line(p1, p3); draw_line(p1, p4); draw_line(p1, p5);
    draw_line(p2, p3); draw_line(p3, p4); draw_line(p4, p5); draw_line(p5, p2);
}

static void draw_skeleton(int debug_draw_idx) {
    sgl_defaults();
    sgl_matrix_mode_projection();
    sgl_load_matrix((const float*)&state.camera.proj);
    sgl_matrix_mode_modelview();
    sgl_load_matrix((const float*)&state.camera.view);

    // initialize the character instance model-to-world matrices
    int i=0, x=0, y=0, dx=0, dy=0;
    for (; i < debug_draw_idx; i++, x+=dx, y+=dy) {
        // at a corner?
        if (abs(x) == abs(y)) {
            if (x >= 0) {
                // top-right corner: start a new ring
                if (y >= 0) { x+=1; y+=1; dx=0; dy=-1; }
                // bottom-right corner
                else { dx=-1; dy=0; }
            }
            else {
                // top-left corner
                if (y >= 0) { dx=+1; dy=0; }
                // bottom-left corner
                else { dx=0; dy=+1; }
            }
        }
    }
    const float instance_offset_x = (float)x * 1.5f;
    const float instance_offset_z = (float)y * 1.5f;
    const ozz::math::SimdFloat4 globalOffset{instance_offset_x, 0, instance_offset_z, 0};

    const int num_joints = state.ozz->skeleton.num_joints();
    ozz::span<const int16_t> joint_parents = state.ozz->skeleton.joint_parents();
    sgl_begin_lines();
    for (int joint_index = 0; joint_index < num_joints; joint_index++) {
        draw_joint(joint_index, joint_parents[joint_index], globalOffset);
    }
    sgl_end();
}

static void draw_ui(void) {
    if (ImGui::BeginMainMenuBar()) {
        sgimgui_draw_menu(&state.ui.sgimgui, "sokol-gfx");
        ImGui::EndMainMenuBar();
    }
    sgimgui_draw(&state.ui.sgimgui);
    ImGui::SetNextWindowPos({ 20, 20 }, ImGuiCond_Once);
    ImGui::SetNextWindowSize({ 220, 150 }, ImGuiCond_Once);
    ImGui::SetNextWindowBgAlpha(0.35f);
    if (ImGui::Begin("Controls", nullptr, ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_AlwaysAutoResize)) {
        if (state.loaded.failed) {
            ImGui::Text("Failed loading character data!");
        }
        else {
            if (ImGui::SliderInt("Num Instances", &state.num_instances, 1, MAX_INSTANCES)) {
                float dist_step = (state.camera.max_dist - state.camera.min_dist) / MAX_INSTANCES;
                state.camera.distance = state.camera.min_dist + dist_step * state.num_instances;
            }
            ImGui::Checkbox("Enable Mesh Drawing", &state.draw_enabled);
            ImGui::Text("Frame Time: %.3fms\n", state.time.frame_time_ms);
            ImGui::Text("Anim Eval Time: %.3fms\n", stm_ms(state.time.anim_eval_time));
            ImGui::Text("Num Triangles: %d\n", (state.num_triangle_indices/3) * state.num_instances);
            ImGui::Text("Num Animated Joints: %d\n", state.num_skeleton_joints * state.num_instances);
            ImGui::Text("Num Skinning Joints: %d\n", state.num_skin_joints * state.num_instances);
            ImGui::Separator();
            ImGui::Text("Camera Controls:");
            ImGui::Text("  LMB + Mouse Move: Look");
            ImGui::Text("  Mouse Wheel: Zoom");
            ImGui::SliderFloat("Distance", &state.camera.distance, state.camera.min_dist, state.camera.max_dist, "%.1f", 1.0f);
            ImGui::SliderFloat("Latitude", &state.camera.latitude, state.camera.min_lat, state.camera.max_lat, "%.1f", 1.0f);
            ImGui::SliderFloat("Longitude", &state.camera.longitude, 0.0f, 360.0f, "%.1f", 1.0f);
            ImGui::Separator();
            ImGui::Text("Time Controls:");
            ImGui::Checkbox("Paused", &state.time.paused);
            ImGui::SliderFloat("Factor", &state.time.factor, 0.0f, 10.0f, "%.1f", 1.0f);
            ImGui::Separator();
            if (ImGui::Button("Toggle Joint Texture")) {
                state.ui.joint_texture_shown = !state.ui.joint_texture_shown;
            }
            ImGui::Separator();
            if (ImGui::Button("Toggle Instance skel")) {
                state.debug_draw_skel = !state.debug_draw_skel;
            }
            if (state.debug_draw_skel) {
                ImGui::SliderInt("Debug Index", &state.debug_draw_index, 0, state.num_instances-1);
            }
        }
    }
    if (state.ui.joint_texture_shown) {
        ImGui::SetNextWindowPos({ 20, 300 }, ImGuiCond_Once);
        ImGui::SetNextWindowSize({ 600, 300 }, ImGuiCond_Once);
        if (ImGui::Begin("Joint Texture", &state.ui.joint_texture_shown)) {
            ImGui::InputInt("##scale", &state.ui.joint_texture_scale);
            ImGui::SameLine();
            if (ImGui::Button("1x")) { state.ui.joint_texture_scale = 1; }
            ImGui::SameLine();
            if (ImGui::Button("2x")) { state.ui.joint_texture_scale = 2; }
            ImGui::SameLine();
            if (ImGui::Button("4x")) { state.ui.joint_texture_scale = 4; }
            ImGui::BeginChild("##frame", {0,0}, true, ImGuiWindowFlags_HorizontalScrollbar);
            ImGui::Image(simgui_imtextureid(state.ui.joint_texture),
                { (float)(state.joint_texture_width * state.ui.joint_texture_scale), (float)(state.joint_texture_height * state.ui.joint_texture_scale) },
                { 0.0f, 0.0f },
                { 1.0f, 1.0f });
            ImGui::EndChild();
        }
        ImGui::End();
    }
    ImGui::End();
}

// FIXME: all loading code is much less efficient than it should be!
static void skel_data_loaded(const std::string& filename) {
    ozz::io::File skel_file(filename.c_str(), "rb");
    if (!skel_file.opened()) {
        state.loaded.failed = true;
        return;
    }

    ozz::io::IArchive archive(&skel_file);
    if (archive.TestTag<ozz::animation::Skeleton>()) {
        archive >> state.ozz->skeleton;
        state.loaded.skeleton = true;
        const int num_soa_joints = state.ozz->skeleton.num_soa_joints();
        const int num_joints = state.ozz->skeleton.num_joints();
        state.ozz->local_matrices.resize(num_soa_joints);
        state.ozz->model_matrices.resize(num_joints);
        state.num_skeleton_joints = num_joints;
        state.ozz->cache.Resize(num_joints);
    }
    else {
        state.loaded.failed = true;
    }
}

static void anim_data_loaded(const std::string& filename) {
    ozz::io::File anim_file(filename.c_str(), "rb");
    if (!anim_file.opened()) {
        state.loaded.failed = true;
        return;
    }

    ozz::io::IArchive archive(&anim_file);
    if (archive.TestTag<ozz::animation::Animation>()) {
        archive >> state.ozz->animation;
        state.loaded.animation = true;
    }
    else {
        state.loaded.failed = true;
    }
}

static uint32_t pack_u32(uint8_t x, uint8_t y, uint8_t z, uint8_t w) {
    return (uint32_t)(((uint32_t)w<<24)|((uint32_t)z<<16)|((uint32_t)y<<8)|x);
}

static uint32_t pack_f4_byte4n(float x, float y, float z, float w) {
    int8_t x8 = (int8_t) (x * 127.0f);
    int8_t y8 = (int8_t) (y * 127.0f);
    int8_t z8 = (int8_t) (z * 127.0f);
    int8_t w8 = (int8_t) (w * 127.0f);
    return pack_u32((uint8_t)x8, (uint8_t)y8, (uint8_t)z8, (uint8_t)w8);
}

static uint32_t pack_f4_ubyte4n(float x, float y, float z, float w) {
    uint8_t x8 = (uint8_t) (x * 255.0f);
    uint8_t y8 = (uint8_t) (y * 255.0f);
    uint8_t z8 = (uint8_t) (z * 255.0f);
    uint8_t w8 = (uint8_t) (w * 255.0f);
    return pack_u32(x8, y8, z8, w8);
}

static void mesh_data_loaded(const std::string& filename) {
    ozz::io::File mesh_file(filename.c_str(), "rb");
    if (!mesh_file.opened()) {
        state.loaded.failed = true;
        return;
    }

    ozz::vector<ozz::sample::Mesh> meshes;
    ozz::io::IArchive archive(&mesh_file);
    while (archive.TestTag<ozz::sample::Mesh>()) {
        meshes.resize(meshes.size() + 1);
        archive >> meshes.back();
    }
    // assume one mesh and one submesh
    assert((meshes.size() == 1) && (meshes[0].parts.size() == 1));
    state.loaded.mesh = true;
    state.num_skin_joints = meshes[0].num_joints();
    state.num_triangle_indices = (int)meshes[0].triangle_index_count();
    state.ozz->joint_remaps = std::move(meshes[0].joint_remaps);
    state.ozz->mesh_inverse_bindposes = std::move(meshes[0].inverse_bind_poses);

    // convert mesh data into packed vertices
    size_t num_vertices = (meshes[0].parts[0].positions.size() / 3);
    assert(meshes[0].parts[0].normals.size() == (num_vertices * 3));
    assert(meshes[0].parts[0].joint_indices.size() == (num_vertices * 4));
    assert(meshes[0].parts[0].joint_weights.size() == (num_vertices * 3));
    const float* positions = &meshes[0].parts[0].positions[0];
    const float* normals = &meshes[0].parts[0].normals[0];
    const uint16_t* joint_indices = &meshes[0].parts[0].joint_indices[0];
    const float* joint_weights = &meshes[0].parts[0].joint_weights[0];
    vertex_t* vertices = (vertex_t*) calloc(num_vertices, sizeof(vertex_t));
    for (int i = 0; i < (int)num_vertices; i++) {
        vertex_t* v = &vertices[i];
        v->position[0] = positions[i * 3 + 0];
        v->position[1] = positions[i * 3 + 1];
        v->position[2] = positions[i * 3 + 2];
        const float nx = normals[i * 3 + 0];
        const float ny = normals[i * 3 + 1];
        const float nz = normals[i * 3 + 2];
        v->normal = pack_f4_byte4n(nx, ny, nz, 0.0f);
        const uint8_t ji0 = (uint8_t) joint_indices[i * 4 + 0];
        const uint8_t ji1 = (uint8_t) joint_indices[i * 4 + 1];
        const uint8_t ji2 = (uint8_t) joint_indices[i * 4 + 2];
        const uint8_t ji3 = (uint8_t) joint_indices[i * 4 + 3];
        v->joint_indices = pack_u32(ji0, ji1, ji2, ji3);
        const float jw0 = joint_weights[i * 3 + 0];
        const float jw1 = joint_weights[i * 3 + 1];
        const float jw2 = joint_weights[i * 3 + 2];
        const float jw3 = 1.0f - (jw0 + jw1 + jw2);
        v->joint_weights = pack_f4_ubyte4n(jw0, jw1, jw2, jw3);
    }

    // create vertex- and index-buffer
    sg_buffer_desc vbuf_desc = { };
    vbuf_desc.type = SG_BUFFERTYPE_VERTEXBUFFER;
    vbuf_desc.data.ptr = vertices;
    vbuf_desc.data.size = num_vertices * sizeof(vertex_t);
    state.bind.vertex_buffers[0] = sg_make_buffer(&vbuf_desc);
    free(vertices); vertices = nullptr;

    sg_buffer_desc ibuf_desc = { };
    ibuf_desc.type = SG_BUFFERTYPE_INDEXBUFFER;
    ibuf_desc.data.ptr = &meshes[0].triangle_indices[0];
    ibuf_desc.data.size = state.num_triangle_indices * sizeof(uint16_t);
    state.bind.index_buffer = sg_make_buffer(&ibuf_desc);
}

sapp_desc sokol_main(int argc, char* argv[]) {
    (void)argc; (void)argv;

    sapp_desc desc = { };
    desc.init_cb = init;
    desc.frame_cb = frame;
    desc.cleanup_cb = cleanup;
    desc.event_cb = input;
    desc.width = 800;
    desc.height = 600;
    desc.sample_count = 4;
    desc.window_title = "ozz_skin.cpp";
    desc.icon.sokol_default = true;
    desc.logger.func = slog_func;

    return desc;
}
