//------------------------------------------------------------------------------
//  ozz-anim-sapp.cc
//
//  https://guillaumeblanc.github.io/ozz-animation/
//
//  Port of the ozz-animation "Animation Playback" sample. Use sokol-gl
//  for debug-rendering the animated character skeleton (no skinning).
//------------------------------------------------------------------------------
#define SOKOL_GLCORE
#define SOKOL_IMPL
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_fetch.h"
#include "sokol_log.h"
#include "sokol_glue.h"
#include "bone.glsl.h"

#define SOKOL_GL_IMPL
#include "sokol_gl.h"

#include "imgui.h"
#define SOKOL_IMGUI_IMPL
#include "sokol_imgui.h"

#define HANDMADE_MATH_IMPLEMENTATION
#define HANDMADE_MATH_NO_SSE
#include "HandmadeMath.h"
#include "util/camera.h"

#include <cmath> // fmodf
#include <ozz_wrap.h>

#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/runtime/skeleton_utils.h>
#include <ozz/base/maths/vec_float.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/memory/allocator.h>

static int
DrawPosture_FillUniforms( // const ozz::animation::Skeleton &_skeleton,
    int num_joints, const int16_t *parents, const int *isLeaf,
    ozz::span<const ozz::math::Float4x4> _matrices, float *_uniforms,
    int _max_instances) {
  assert(ozz::IsAligned(_uniforms, alignof(ozz::math::SimdFloat4)));

  // Prepares computation constants.
  // const int num_joints = _skeleton.num_joints();
  // const ozz::span<const int16_t> &parents = _skeleton.joint_parents();

  int instances = 0;
  for (int i = 0; i < num_joints && instances < _max_instances; ++i) {
    // Root isn't rendered.
    const int16_t parent_id = parents[i];
    if (parent_id == ozz::animation::Skeleton::kNoParent) {
      continue;
    }

    // Selects joint matrices.
    const ozz::math::Float4x4 &parent = _matrices[parent_id];
    const ozz::math::Float4x4 &current = _matrices[i];

    // Copy parent joint's raw matrix, to render a bone between the parent
    // and current matrix.
    float *uniform = _uniforms + instances * 16;
    memcpy(uniform, parent.cols, 16 * sizeof(float));

    // Set bone direction (bone_dir). The shader expects to find it at index
    // [3,7,11] of the matrix.
    // Index 15 is used to store whether a bone should be rendered,
    // otherwise it's a leaf.
    float bone_dir[4];
    ozz::math::StorePtrU(current.cols[3] - parent.cols[3], bone_dir);
    uniform[3] = bone_dir[0];
    uniform[7] = bone_dir[1];
    uniform[11] = bone_dir[2];
    uniform[15] = 1.f; // Enables bone rendering.

    // Next instance.
    ++instances;
    uniform += 16;

    // Only the joint is rendered for leaves, the bone model isn't.
    if (isLeaf[i]) {
      // Copy current joint's raw matrix.
      memcpy(uniform, current.cols, 16 * sizeof(float));

      // Re-use bone_dir to fix the size of the leaf (same as previous bone).
      // The shader expects to find it at index [3,7,11] of the matrix.
      uniform[3] = bone_dir[0];
      uniform[7] = bone_dir[1];
      uniform[11] = bone_dir[2];
      uniform[15] = 0.f; // Disables bone rendering.
      ++instances;
    }
  }

  return instances;
}

class ScratchBuffer {
  void *buffer_ = nullptr;
  size_t size_ = 0;

public:
  ~ScratchBuffer() { ozz::memory::default_allocator()->Deallocate(buffer_); }

  // Resizes the buffer to the new size and return the memory address.
  void *Resize(size_t _size) {
    if (_size > size_) {
      size_ = _size;
      ozz::memory::default_allocator()->Deallocate(buffer_);
      buffer_ = ozz::memory::default_allocator()->Allocate(_size, 16);
    }
    return buffer_;
  }
};

// A vertex made of positions and normals.
struct Color {
  unsigned char r, g, b, a;
};

struct VertexPNC {
  ozz::math::Float3 pos;
  ozz::math::Float3 normal;
  Color color;
};

class Renderer {
  // Volatile memory buffer that can be used within function scope.
  // Minimum alignment is 16 bytes.
  ScratchBuffer scratch_buffer_;

public:
  bool InitPosture() {
    const float kInter = .2f;
    { // Prepares bone mesh.
      const ozz::math::Float3 pos[6] = {ozz::math::Float3(1.f, 0.f, 0.f),
                                        ozz::math::Float3(kInter, .1f, .1f),
                                        ozz::math::Float3(kInter, .1f, -.1f),
                                        ozz::math::Float3(kInter, -.1f, -.1f),
                                        ozz::math::Float3(kInter, -.1f, .1f),
                                        ozz::math::Float3(0.f, 0.f, 0.f)};
      const ozz::math::Float3 normals[8] = {
          Normalize(Cross(pos[2] - pos[1], pos[2] - pos[0])),
          Normalize(Cross(pos[1] - pos[2], pos[1] - pos[5])),
          Normalize(Cross(pos[3] - pos[2], pos[3] - pos[0])),
          Normalize(Cross(pos[2] - pos[3], pos[2] - pos[5])),
          Normalize(Cross(pos[4] - pos[3], pos[4] - pos[0])),
          Normalize(Cross(pos[3] - pos[4], pos[3] - pos[5])),
          Normalize(Cross(pos[1] - pos[4], pos[1] - pos[0])),
          Normalize(Cross(pos[4] - pos[1], pos[4] - pos[5]))};
      const Color white = {0xff, 0xff, 0xff, 0xff};
      const VertexPNC bones[24] = {
          {pos[0], normals[0], white}, {pos[2], normals[0], white},
          {pos[1], normals[0], white}, {pos[5], normals[1], white},
          {pos[1], normals[1], white}, {pos[2], normals[1], white},
          {pos[0], normals[2], white}, {pos[3], normals[2], white},
          {pos[2], normals[2], white}, {pos[5], normals[3], white},
          {pos[2], normals[3], white}, {pos[3], normals[3], white},
          {pos[0], normals[4], white}, {pos[4], normals[4], white},
          {pos[3], normals[4], white}, {pos[5], normals[5], white},
          {pos[3], normals[5], white}, {pos[4], normals[5], white},
          {pos[0], normals[6], white}, {pos[1], normals[6], white},
          {pos[4], normals[6], white}, {pos[5], normals[7], white},
          {pos[4], normals[7], white}, {pos[1], normals[7], white}};

      // Builds and fills the vbo.
      // Model &bone = models_[0];
      // bone.mode = GL_TRIANGLES;
      // bone.count = OZZ_ARRAY_SIZE(bones);
      // GL(GenBuffers(1, &bone.vbo));
      // GL(BindBuffer(GL_ARRAY_BUFFER, bone.vbo));
      // GL(BufferData(GL_ARRAY_BUFFER, sizeof(bones), bones, GL_STATIC_DRAW));
      // GL(BindBuffer(GL_ARRAY_BUFFER, 0)); // Unbinds.

      // Init bone shader.
      // bone.shader = BoneShader::Build();
      // if (!bone.shader) {
      //   return false;
      // }
    }

    { // Prepares joint mesh.
      const int kNumSlices = 20;
      const int kNumPointsPerCircle = kNumSlices + 1;
      const int kNumPointsYZ = kNumPointsPerCircle;
      const int kNumPointsXY = kNumPointsPerCircle + kNumPointsPerCircle / 4;
      const int kNumPointsXZ = kNumPointsPerCircle;
      const int kNumPoints = kNumPointsXY + kNumPointsXZ + kNumPointsYZ;
      const float kRadius = kInter; // Radius multiplier.
      const Color red = {0xff, 0xc0, 0xc0, 0xff};
      const Color green = {0xc0, 0xff, 0xc0, 0xff};
      const Color blue = {0xc0, 0xc0, 0xff, 0xff};
      VertexPNC joints[kNumPoints];

      // Fills vertices.
      int index = 0;
      for (int j = 0; j < kNumPointsYZ; ++j) { // YZ plan.
        float angle = j * ozz::math::k2Pi / kNumSlices;
        float s = sinf(angle), c = cosf(angle);
        VertexPNC &vertex = joints[index++];
        vertex.pos = ozz::math::Float3(0.f, c * kRadius, s * kRadius);
        vertex.normal = ozz::math::Float3(0.f, c, s);
        vertex.color = red;
      }
      for (int j = 0; j < kNumPointsXY; ++j) { // XY plan.
        float angle = j * ozz::math::k2Pi / kNumSlices;
        float s = sinf(angle), c = cosf(angle);
        VertexPNC &vertex = joints[index++];
        vertex.pos = ozz::math::Float3(s * kRadius, c * kRadius, 0.f);
        vertex.normal = ozz::math::Float3(s, c, 0.f);
        vertex.color = blue;
      }
      for (int j = 0; j < kNumPointsXZ; ++j) { // XZ plan.
        float angle = j * ozz::math::k2Pi / kNumSlices;
        float s = sinf(angle), c = cosf(angle);
        VertexPNC &vertex = joints[index++];
        vertex.pos = ozz::math::Float3(c * kRadius, 0.f, -s * kRadius);
        vertex.normal = ozz::math::Float3(c, 0.f, -s);
        vertex.color = green;
      }
      assert(index == kNumPoints);

      // Builds and fills the vbo.
      // Model &joint = models_[1];
      // joint.mode = GL_LINE_STRIP;
      // joint.count = OZZ_ARRAY_SIZE(joints);
      // GL(GenBuffers(1, &joint.vbo));
      // GL(BindBuffer(GL_ARRAY_BUFFER, joint.vbo));
      // GL(BufferData(GL_ARRAY_BUFFER, sizeof(joints), joints, GL_STATIC_DRAW));
      // GL(BindBuffer(GL_ARRAY_BUFFER, 0)); // Unbinds.
      //
      // // Init joint shader.
      // joint.shader = JointShader::Build();
      // if (!joint.shader) {
      //   return false;
      // }
    }

    return true;
  }

  // Uses GL_ARB_instanced_arrays_supported as a first choice to render the
  // whole skeleton in a single draw call. Does a draw call per joint if no
  // extension can help.
  void DrawPosture(ozz_t *ozz, ozz::span<const ozz::math::Float4x4> _matrices,
                   const ozz::math::Float4x4 &_transform, bool _draw_joints) {
    if (_matrices.size() < static_cast<size_t>(OZZ_num_joints(ozz))) {
      return;
    }

    // Convert matrices to uniforms.
    const int max_skeleton_pieces = ozz::animation::Skeleton::kMaxJoints * 2;
    const size_t max_uniforms_size =
        max_skeleton_pieces * 2 * 16 * sizeof(float);
    float *uniforms =
        static_cast<float *>(scratch_buffer_.Resize(max_uniforms_size));

    const int instance_count = DrawPosture_FillUniforms(
        // _skeleton,
        OZZ_num_joints(ozz), OZZ_joint_parents(ozz), OZZ_is_leaf(ozz),
        _matrices, uniforms, max_skeleton_pieces);
    assert(instance_count <= max_skeleton_pieces);

    // if (GL_ARB_instanced_arrays_supported) {
    // DrawPosture_InstancedImpl(_transform, uniforms, instance_count,
    //                           _draw_joints);
    // } else {
    //   DrawPosture_Impl(_transform, uniforms, instance_count, _draw_joints);
    // }
  }

  // Draw posture internal non-instanced rendering fall back implementation.
  void DrawPosture_Impl(const ozz::math::Float4x4 &_transform,
                        const float *_uniforms, int _instance_count,
                        bool _draw_joints) {
    // Loops through models and instances.
    // for (int i = 0; i < (_draw_joints ? 2 : 1); ++i) {
    //   const Model &model = models_[i];
    //
    //   // Setup model vertex data.
    //   GL(BindBuffer(GL_ARRAY_BUFFER, model.vbo));
    //
    //   // Bind shader
    //   model.shader->Bind(_transform, camera_->view_proj(), sizeof(VertexPNC),
    //   0,
    //                      sizeof(VertexPNC), 12, sizeof(VertexPNC), 24);

    // GL(BindBuffer(GL_ARRAY_BUFFER, 0));

    // Draw loop.
    // const GLint joint_uniform = model.shader->joint_uniform();
    // for (int j = 0; j < _instance_count; ++j) {
    //   // GL(UniformMatrix4fv(joint_uniform, 1, false, _uniforms + 16 * j));
    //   // GL(DrawArrays(model.mode, 0, model.count));
    // }

    // model.shader->Unbind();
    // }
  }
};

static struct {
  ozz_t *ozz = nullptr;
  sg_pass_action pass_action;
  camera_t camera;
  struct {
    bool skeleton;
    bool animation;
    bool failed;
  } loaded;
  struct {
    double frame;
    double absolute;
    float factor;
    float anim_ratio;
    bool anim_ratio_ui_override;
    bool paused;
  } time;
  Renderer renderer;
} state;

// io buffers for skeleton and animation data files, we know the max file size
// upfront
static uint8_t skel_data_buffer[4 * 1024];
static uint8_t anim_data_buffer[32 * 1024];

static void draw_ui(void);
static void skeleton_data_loaded(const sfetch_response_t *response);
static void animation_data_loaded(const sfetch_response_t *response);

static const char *fileutil_get_path(const char *filename, char *buf,
                                     size_t buf_size) {
  snprintf(buf, buf_size, "%s", filename);
  return buf;
}

static void init(void) {
  state.ozz = OZZ_init();
  state.time.factor = 1.0f;

  // setup sokol-gfx
  sg_desc sgdesc = {};
  sgdesc.environment = sglue_environment(), sgdesc.logger.func = slog_func;
  sg_setup(&sgdesc);

  // setup sokol-fetch
  sfetch_desc_t sfdesc = {};
  sfdesc.max_requests = 2;
  sfdesc.num_channels = 1;
  sfdesc.num_lanes = 2;
  sfdesc.logger.func = slog_func;
  sfetch_setup(&sfdesc);

  // setup sokol-gl
  sgl_desc_t sgldesc = {};
  sgldesc.sample_count = sapp_sample_count();
  sgldesc.logger.func = slog_func;
  sgl_setup(&sgldesc);

  // setup sokol-imgui
  simgui_desc_t imdesc = {};
  imdesc.logger.func = slog_func;
  simgui_setup(&imdesc);

  // initialize pass action for default-pass
  state.pass_action.colors[0].load_action = SG_LOADACTION_CLEAR;
  state.pass_action.colors[0].clear_value = {0.0f, 0.1f, 0.2f, 1.0f};

  // initialize camera helper
  camera_desc_t camdesc = {};
  camdesc.min_dist = 1.0f;
  camdesc.max_dist = 10.0f;
  camdesc.center.Y = 1.0f;
  camdesc.distance = 3.0f;
  camdesc.latitude = 10.0f;
  camdesc.longitude = 20.0f;
  cam_init(&state.camera, &camdesc);

  // start loading the skeleton and animation files
  char path_buf[512];
  {
    sfetch_request_t req = {};
    req.path = fileutil_get_path("media/bin/pab_skeleton.ozz", path_buf,
                                 sizeof(path_buf));
    req.callback = skeleton_data_loaded;
    req.buffer = SFETCH_RANGE(skel_data_buffer);
    sfetch_send(&req);
  }
  {
    sfetch_request_t req = {};
    req.path = fileutil_get_path("media/bin/pab_crossarms.ozz", path_buf,
                                 sizeof(path_buf));
    req.callback = animation_data_loaded;
    req.buffer = SFETCH_RANGE(anim_data_buffer);
    sfetch_send(&req);
  }
}

static void frame(void) {
  sfetch_dowork();

  const int fb_width = sapp_width();
  const int fb_height = sapp_height();
  state.time.frame = sapp_frame_duration();
  cam_update(&state.camera, fb_width, fb_height);

  simgui_new_frame({fb_width, fb_height, state.time.frame, sapp_dpi_scale()});
  draw_ui();

  if (state.loaded.animation && state.loaded.skeleton) {
    if (!state.time.paused) {
      state.time.absolute += state.time.frame * state.time.factor;
    }

    // convert current time to animation ration (0.0 .. 1.0)
    const float anim_duration = OZZ_duration(state.ozz);
    if (!state.time.anim_ratio_ui_override) {
      state.time.anim_ratio =
          fmodf((float)state.time.absolute / anim_duration, 1.0f);
    }
    OZZ_eval_animation(state.ozz, state.time.anim_ratio);

    size_t num = OZZ_num_joints(state.ozz);
    auto pMatrix =
        (const ozz::math::Float4x4 *)OZZ_model_matrices(state.ozz, 0);
    state.renderer.DrawPosture(state.ozz, ozz::span{pMatrix, num},
                               ozz::math::Float4x4::identity(), true);
  }

  sg_pass pass = {};
  pass.action = state.pass_action;
  pass.swapchain = sglue_swapchain();
  sg_begin_pass(&pass);
  sgl_draw();
  simgui_render();
  sg_end_pass();
  sg_commit();
}

static void input(const sapp_event *ev) {
  if (simgui_handle_event(ev)) {
    return;
  }
  cam_handle_event(&state.camera, ev);
}

static void cleanup(void) {
  simgui_shutdown();
  sgl_shutdown();
  sfetch_shutdown();
  sg_shutdown();

  OZZ_shutdown(state.ozz);
  state.ozz = nullptr;
}

static void draw_ui(void) {
  ImGui::SetNextWindowPos({20, 20}, ImGuiCond_Once);
  ImGui::SetNextWindowSize({220, 150}, ImGuiCond_Once);
  ImGui::SetNextWindowBgAlpha(0.35f);
  if (ImGui::Begin("Controls", nullptr,
                   ImGuiWindowFlags_NoDecoration |
                       ImGuiWindowFlags_AlwaysAutoResize)) {
    if (state.loaded.failed) {
      ImGui::Text("Failed loading character data!");
    } else {
      ImGui::Text("Camera Controls:");
      ImGui::Text("  LMB + Mouse Move: Look");
      ImGui::Text("  Mouse Wheel: Zoom");
      ImGui::SliderFloat("Distance", &state.camera.distance,
                         state.camera.min_dist, state.camera.max_dist, "%.1f",
                         1.0f);
      ImGui::SliderFloat("Latitude", &state.camera.latitude,
                         state.camera.min_lat, state.camera.max_lat, "%.1f",
                         1.0f);
      ImGui::SliderFloat("Longitude", &state.camera.longitude, 0.0f, 360.0f,
                         "%.1f", 1.0f);
      ImGui::Separator();
      ImGui::Text("Time Controls:");
      ImGui::Checkbox("Paused", &state.time.paused);
      ImGui::SliderFloat("Factor", &state.time.factor, 0.0f, 10.0f, "%.1f",
                         1.0f);
      if (ImGui::SliderFloat("Ratio", &state.time.anim_ratio, 0.0f, 1.0f)) {
        state.time.anim_ratio_ui_override = true;
      }
      if (ImGui::IsItemDeactivatedAfterEdit()) {
        state.time.anim_ratio_ui_override = false;
      }
    }
  }
  ImGui::End();
}

static void skeleton_data_loaded(const sfetch_response_t *response) {
  if (response->fetched) {
    if (OZZ_load_skeleton(state.ozz, response->data.ptr, response->data.size)) {
      state.loaded.skeleton = true;
    } else {
      state.loaded.failed = true;
    }
  } else if (response->failed) {
    state.loaded.failed = true;
  }
}

static void animation_data_loaded(const sfetch_response_t *response) {
  if (response->fetched) {
    if (OZZ_load_animation(state.ozz, response->data.ptr,
                           response->data.size)) {
      state.loaded.animation = true;
    } else {
      state.loaded.failed = true;
    }
  } else if (response->failed) {
    state.loaded.failed = true;
  }
}

sapp_desc sokol_main(int argc, char *argv[]) {
  (void)argc;
  (void)argv;

  sapp_desc desc = {};
  desc.init_cb = init;
  desc.frame_cb = frame;
  desc.cleanup_cb = cleanup;
  desc.event_cb = input;
  desc.width = 800;
  desc.height = 600;
  desc.sample_count = 4;
  desc.window_title = "ozz-anim-sapp.cc";
  desc.icon.sokol_default = true;
  desc.logger.func = slog_func;

  return desc;
}
