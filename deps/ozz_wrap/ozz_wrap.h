#pragma once
// size_t
#include <stddef.h>
// bool
#include <stdbool.h>
// uint32_t
#include <stdint.h>

#if _MSC_VER
#ifdef DLL_EXPORTS
#define DECLSPEC __declspec(dllexport)
#else
#define DECLSPEC __declspec(dllimport)
#endif

#else
#define DECLSPEC __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ozz_t ozz_t;

// ozz
DECLSPEC ozz_t *OZZ_init();
DECLSPEC void OZZ_shutdown(ozz_t *p);

typedef void *(*aligned_alloc_func)(size_t _size, size_t _alignment);
typedef void (*dealloc_func)(void *_block);
DECLSPEC void OZZ_set_allocator(aligned_alloc_func alloc, dealloc_func dealloc);
DECLSPEC size_t OZZ_align(size_t addr, size_t alignment);

// skeleton
DECLSPEC bool OZZ_load_skeleton(ozz_t *p, const void *ptr, size_t size);
DECLSPEC size_t OZZ_num_joints(ozz_t *p);
DECLSPEC const unsigned short *OZZ_joint_parents(ozz_t *p);
DECLSPEC const char *const *OZZ_joint_names(ozz_t *p);
DECLSPEC const bool OZZ_joint_is_leaf(ozz_t *p, size_t i);
DECLSPEC const void OZZ_skeleton_trs(ozz_t *ozz, size_t joint_index,
                                     float pOutT[3], float pOutR[4],
                                     float pOutS[3]);

// animation
DECLSPEC bool OZZ_load_animation(ozz_t *p, const void *ptr, size_t size);
DECLSPEC void OZZ_eval_animation(ozz_t *p, float anim_ratio);
DECLSPEC float OZZ_duration(ozz_t *p);
DECLSPEC const float *OZZ_model_matrices(ozz_t *ozz);

// mesh
typedef struct vertex_t {
  float position[3];
  uint32_t normal;
  uint32_t joint_indices;
  uint32_t joint_weights;
} vertex_t;
DECLSPEC bool OZZ_load_mesh(ozz_t *p, const void *ptr, size_t size,
                            vertex_t **vertices, int *num_vertices,
                            uint16_t **indices, int *num_triangle_indices);
DECLSPEC void OZZ_free(void *p);
DECLSPEC void OZZ_update_joints(ozz_t *ozz, int num_instances,
                                float abs_time_sec, float *joint_upload_buffer,
                                int max_joints);

// offline skeleton
DECLSPEC const unsigned short *
OZZ_raw_skeleton_add_trs(ozz_t *p, const unsigned short *path, const char *name,
                         const float *t, const float *r, const float *s);
DECLSPEC size_t OZZ_raw_num_joints(ozz_t *p);
DECLSPEC bool OZZ_raw_build(ozz_t *p);

// offline animation
DECLSPEC void OZZ_raw_animation(ozz_t *p, float duration, size_t tracks);
DECLSPEC void OZZ_track_push_translation(ozz_t *p, size_t track_index,
                                         float time, const float *t);
DECLSPEC void OZZ_track_push_rotation(ozz_t *p, size_t track_index, float time,
                                      const float *r);
DECLSPEC bool OZZ_animation_build(ozz_t *p);

#ifdef __cplusplus
} // extern "C"
#endif
