#include "ozz_wrap.h"

#include <string.h>

// ozz-animation headers
#include "ozz/animation/runtime/animation.h"
#include "ozz/animation/runtime/local_to_model_job.h"
#include "ozz/animation/runtime/sampling_job.h"
#include "ozz/animation/runtime/skeleton.h"
#include "ozz/animation/runtime/skeleton_utils.h"
#include "ozz/base/containers/vector.h"
#include "ozz/base/io/archive.h"
#include "ozz/base/io/stream.h"
#include "ozz/base/maths/soa_transform.h"
#include "ozz/animation/runtime/sampling_job.h"

#include "ozz/animation/offline/raw_skeleton.h"
#include "ozz/animation/offline/skeleton_builder.h"

// #include "samples/framework/mesh.h"

extern "C" {

// a skinned-mesh vertex, we don't need the texcoords and tangent
// in our example renderer so we just drop them. Normals, joint indices
// and joint weights are packed into BYTE4N and UBYTE4N
//
// NOTE: joint indices are packed as UBYTE4N and not UBYTE4 because of
// D3D11 compatibility (see "A NOTE ON PORTABLE PACKED VERTEX FORMATS" in
// sokol_gfx.h)
struct vertex_t {
  float position[3];
  uint32_t normal;
  uint32_t joint_indices;
  uint32_t joint_weights;
};
static_assert(sizeof(vertex_t) == 24, "vertex_t");

// wrapper struct for managed ozz-animation C++ objects, must be deleted
// before shutdown, otherwise ozz-animation will report a memory leak
struct ozz_t {
  // runtime
  ozz::animation::Skeleton skeleton;
  ozz::animation::Animation animation;
  ozz::animation::SamplingJob::Context context;
  ozz::vector<ozz::math::SoaTransform> local_matrices;
  ozz::vector<ozz::math::Float4x4> model_matrices;

  std::vector<unsigned short> joint_path_stack;
  ozz::animation::offline::RawSkeleton raw_skeleton;

  void on_load_skeleton() {
    const int num_soa_joints = this->skeleton.num_soa_joints();
    const int num_joints = this->skeleton.num_joints();
    this->local_matrices.resize(num_soa_joints);
    this->model_matrices.resize(num_joints);
    this->context.Resize(num_joints);

    // convert joint matrices from local to model space
    ozz::animation::LocalToModelJob ltm_job;
    ltm_job.skeleton = &this->skeleton;
    ltm_job.input = make_span(this->skeleton.joint_rest_poses());
    ltm_job.output = make_span(this->model_matrices);
    ltm_job.Run();
  }

  ozz::animation::offline::RawSkeleton::Joint *
  get_joint(const unsigned short *path,
            ozz::animation::offline::RawSkeleton::Joint *current = nullptr) {
    if (path[0] == std::numeric_limits<unsigned short>::max()) {
      joint_path_stack.push_back(std::numeric_limits<unsigned short>::max());
      return current;
    }

    if (current) {
      joint_path_stack.push_back(path[0]);
      return get_joint(path + 1, &current->children[path[0]]);
    }

    joint_path_stack.push_back(path[0]);
    joint_path_stack.push_back(std::numeric_limits<unsigned short>::max());
    return &raw_skeleton.roots[path[0]];
  }

  ozz::animation::offline::RawSkeleton::Joint *
  add_joint(const unsigned short *path) {
    joint_path_stack.clear();
    if (!path) {
      joint_path_stack.push_back(raw_skeleton.roots.size());
      joint_path_stack.push_back(std::numeric_limits<unsigned short>::max());
      raw_skeleton.roots.push_back({});
      return &raw_skeleton.roots.back();
    }

    auto parent = get_joint(path);
    joint_path_stack.back() = parent->children.size();
    joint_path_stack.push_back(std::numeric_limits<unsigned short>::max());
    parent->children.push_back({});
    return &parent->children.back();
  }

  // mesh skinning
  // ozz::vector<uint16_t> joint_remaps;
  // ozz::vector<ozz::math::Float4x4> mesh_inverse_bindposes;
};

ozz_t *OZZ_init() { return new ozz_t; }
void OZZ_shutdown(ozz_t *p) { delete (p); }

//
// skeleton
//
bool OZZ_load_skeleton(ozz_t *p, const void *ptr, size_t size) {
  // NOTE: if we derived our own ozz::io::Stream class we could
  // avoid the extra allocation and memory copy that happens
  // with the standard MemoryStream class
  ozz::io::MemoryStream stream;
  stream.Write(ptr, size);
  stream.Seek(0, ozz::io::Stream::kSet);
  ozz::io::IArchive archive(&stream);
  if (archive.TestTag<ozz::animation::Skeleton>()) {
    archive >> p->skeleton;

    p->on_load_skeleton();

    return true;
  } else {
    return false;
  }
}

size_t OZZ_num_joints(ozz_t *p) { return p->skeleton.num_joints(); }

const unsigned short *OZZ_joint_parents(ozz_t *p) {
  return (const unsigned short *)p->skeleton.joint_parents().data();
}

const char *const *OZZ_joint_names(ozz_t *p) {
  return p->skeleton.joint_names().data();
}

const bool OZZ_joint_is_leaf(ozz_t *p, size_t i) {
  return IsLeaf(p->skeleton, i);
}

const void OZZ_skeleton_trs(ozz_t *ozz, size_t joint_index, float pOutT[3],
                            float pOutR[4], float pOutS[3]) {
  auto t = ozz::animation::GetJointLocalRestPose(ozz->skeleton, joint_index);
  if (pOutT) {
    *((ozz::math::Float3 *)pOutT) = t.translation;
  }
  if (pOutR) {
    *((ozz::math::Quaternion *)pOutR) = t.rotation;
  }
  if (pOutS) {
    *((ozz::math::Float3 *)pOutS) = t.scale;
  }
}

//
// animation
//
bool OZZ_load_animation(ozz_t *p, const void *ptr, size_t size) {
  ozz::io::MemoryStream stream;
  stream.Write(ptr, size);
  stream.Seek(0, ozz::io::Stream::kSet);
  ozz::io::IArchive archive(&stream);
  if (archive.TestTag<ozz::animation::Animation>()) {
    archive >> p->animation;
    return true;
  } else {
    return false;
  }
}

void OZZ_eval_animation(ozz_t *p, float anim_ratio) {
  // sample animation
  ozz::animation::SamplingJob sampling_job;
  sampling_job.animation = &p->animation;
  sampling_job.context = &p->context;
  sampling_job.ratio = anim_ratio;
  sampling_job.output = make_span(p->local_matrices);
  sampling_job.Run();

  // convert joint matrices from local to model space
  ozz::animation::LocalToModelJob ltm_job;
  ltm_job.skeleton = &p->skeleton;
  ltm_job.input = make_span(p->local_matrices);
  ltm_job.output = make_span(p->model_matrices);
  ltm_job.Run();
}

float OZZ_duration(ozz_t *p) { return p->animation.duration(); }

const float *OZZ_model_matrices(ozz_t *ozz) {
  return (float *)ozz->model_matrices.data();
}

// void OZZ_update_joints(ozz_t *p, int num_instances, float abs_time_sec,
//                        float *joint_upload_buffer, int max_joints) {
//   auto anim_duration = p->animation.duration();
//   for (int instance = 0; instance < num_instances; instance++) {
//     // each character instance evaluates its own animation
//     const float anim_ratio =
//         fmodf(((float)abs_time_sec + (instance * 0.1f)) /
//         anim_duration, 1.0f);
//
//     // sample animation
//     // NOTE: using one cache per instance versus one cache per animation
//     // makes a small difference, but not much
//     ozz::animation::SamplingJob sampling_job;
//     sampling_job.animation = &p->animation;
//     sampling_job.context = &p->context;
//     sampling_job.ratio = anim_ratio;
//     sampling_job.output = make_span(p->local_matrices);
//     sampling_job.Run();
//
//     // convert joint matrices from local to model space
//     ozz::animation::LocalToModelJob ltm_job;
//     ltm_job.skeleton = &p->skeleton;
//     ltm_job.input = make_span(p->local_matrices);
//     ltm_job.output = make_span(p->model_matrices);
//     ltm_job.Run();
//
//     // compute skinning matrices and write to joint texture upload buffer
//     auto ptr = &joint_upload_buffer[instance * max_joints * 12];
//     for (int i = 0; i < p->num_skin_joints; i++) {
//       ozz::math::Float4x4 skin_matrix =
//           p->model_matrices[p->joint_remaps[i]] *
//           p->mesh_inverse_bindposes[i];
//       const ozz::math::SimdFloat4 &c0 = skin_matrix.cols[0];
//       const ozz::math::SimdFloat4 &c1 = skin_matrix.cols[1];
//       const ozz::math::SimdFloat4 &c2 = skin_matrix.cols[2];
//       const ozz::math::SimdFloat4 &c3 = skin_matrix.cols[3];
//
//       // float *ptr = &joint_upload_buffer[instance * (i * max_joints) * 12];
//       *ptr++ = ozz::math::GetX(c0);
//       *ptr++ = ozz::math::GetX(c1);
//       *ptr++ = ozz::math::GetX(c2);
//       *ptr++ = ozz::math::GetX(c3);
//       *ptr++ = ozz::math::GetY(c0);
//       *ptr++ = ozz::math::GetY(c1);
//       *ptr++ = ozz::math::GetY(c2);
//       *ptr++ = ozz::math::GetY(c3);
//       *ptr++ = ozz::math::GetZ(c0);
//       *ptr++ = ozz::math::GetZ(c1);
//       *ptr++ = ozz::math::GetZ(c2);
//       *ptr++ = ozz::math::GetZ(c3);
//     }
//   }
// }

//
// mesh
//
static uint32_t pack_u32(uint8_t x, uint8_t y, uint8_t z, uint8_t w) {
  return (uint32_t)(((uint32_t)w << 24) | ((uint32_t)z << 16) |
                    ((uint32_t)y << 8) | x);
}

static uint32_t pack_f4_byte4n(float x, float y, float z, float w) {
  int8_t x8 = (int8_t)(x * 127.0f);
  int8_t y8 = (int8_t)(y * 127.0f);
  int8_t z8 = (int8_t)(z * 127.0f);
  int8_t w8 = (int8_t)(w * 127.0f);
  return pack_u32((uint8_t)x8, (uint8_t)y8, (uint8_t)z8, (uint8_t)w8);
}

static uint32_t pack_f4_ubyte4n(float x, float y, float z, float w) {
  uint8_t x8 = (uint8_t)(x * 255.0f);
  uint8_t y8 = (uint8_t)(y * 255.0f);
  uint8_t z8 = (uint8_t)(z * 255.0f);
  uint8_t w8 = (uint8_t)(w * 255.0f);
  return pack_u32(x8, y8, z8, w8);
}

// bool OZZ_load_mesh(ozz_t *p, const void *ptr, size_t size, void **_vertices,
//                    int *num_vertices, void **indices,
//                    int *num_triangle_indices) {
//   ozz::io::MemoryStream stream;
//   stream.Write(ptr, size);
//   stream.Seek(0, ozz::io::Stream::kSet);
//
//   ozz::vector<ozz::sample::Mesh> meshes;
//   ozz::io::IArchive archive(&stream);
//   while (archive.TestTag<ozz::sample::Mesh>()) {
//     meshes.resize(meshes.size() + 1);
//     archive >> meshes.back();
//   }
//   // assume one mesh and one submesh
//   assert((meshes.size() == 1) && (meshes[0].parts.size() == 1));
//
//   *num_triangle_indices = (int)meshes[0].triangle_index_count();
//
//   p->num_skin_joints = meshes[0].num_joints();
//   p->joint_remaps = std::move(meshes[0].joint_remaps);
//   p->mesh_inverse_bindposes = std::move(meshes[0].inverse_bind_poses);
//
//   // convert mesh data into packed vertices
//   *num_vertices = (meshes[0].parts[0].positions.size() / 3);
//   assert(meshes[0].parts[0].normals.size() == (*num_vertices * 3));
//   assert(meshes[0].parts[0].joint_indices.size() == (*num_vertices * 4));
//   assert(meshes[0].parts[0].joint_weights.size() == (*num_vertices * 3));
//   const float *positions = &meshes[0].parts[0].positions[0];
//   const float *normals = &meshes[0].parts[0].normals[0];
//   const uint16_t *joint_indices = &meshes[0].parts[0].joint_indices[0];
//   const float *joint_weights = &meshes[0].parts[0].joint_weights[0];
//   auto vertices = (vertex_t *)calloc(*num_vertices, sizeof(vertex_t));
//   for (int i = 0; i < (int)*num_vertices; i++) {
//     vertex_t *v = &(vertices)[i];
//     v->position[0] = positions[i * 3 + 0];
//     v->position[1] = positions[i * 3 + 1];
//     v->position[2] = positions[i * 3 + 2];
//     const float nx = normals[i * 3 + 0];
//     const float ny = normals[i * 3 + 1];
//     const float nz = normals[i * 3 + 2];
//     v->normal = pack_f4_byte4n(nx, ny, nz, 0.0f);
//     const uint8_t ji0 = (uint8_t)joint_indices[i * 4 + 0];
//     const uint8_t ji1 = (uint8_t)joint_indices[i * 4 + 1];
//     const uint8_t ji2 = (uint8_t)joint_indices[i * 4 + 2];
//     const uint8_t ji3 = (uint8_t)joint_indices[i * 4 + 3];
//     v->joint_indices = pack_u32(ji0, ji1, ji2, ji3);
//     const float jw0 = joint_weights[i * 3 + 0];
//     const float jw1 = joint_weights[i * 3 + 1];
//     const float jw2 = joint_weights[i * 3 + 2];
//     const float jw3 = 1.0f - (jw0 + jw1 + jw2);
//     v->joint_weights = pack_f4_ubyte4n(jw0, jw1, jw2, jw3);
//   }
//
//   *_vertices = vertices;
//   *indices = malloc(sizeof(uint16_t) * *num_triangle_indices);
//   memcpy(*indices, &meshes[0].triangle_indices[0],
//          sizeof(uint16_t) * *num_triangle_indices);
//
//   return true;
// }

const uint16_t *OZZ_raw_skeleton_add_trs(ozz_t *p, const uint16_t *path,
                                         const char *name, const float *t,
                                         const float *r, const float *s) {
  auto joint = p->add_joint(path);

  joint->name = name;
  joint->transform.translation = *((const ozz::math::Float3 *)t);
  joint->transform.rotation = *((const ozz::math::Quaternion *)r);
  joint->transform.scale = *((const ozz::math::Float3 *)s);

  return p->joint_path_stack.data();
}

size_t OZZ_raw_num_joints(ozz_t *p) { return p->raw_skeleton.num_joints(); }

bool OZZ_raw_build(ozz_t *p) {
  ozz::animation::offline::SkeletonBuilder skeleton_builder;
  auto skeleton = skeleton_builder(p->raw_skeleton);
  if (!skeleton) {
    return false;
  }
  p->skeleton = std::move(*skeleton);

  p->on_load_skeleton();

  return true;
}

} // extern "C"
