#pragma once
#include <stddef.h>

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

struct ozz_t;

DECLSPEC ozz_t *OZZ_init();
DECLSPEC void OZZ_shutdown(void *p);
DECLSPEC bool OZZ_load_skeleton(ozz_t *p, const void *ptr, size_t size);
DECLSPEC bool OZZ_load_animation(ozz_t *p, const void *ptr, size_t size);
DECLSPEC bool OZZ_load_mesh(ozz_t *p, const void *ptr, size_t size,
                            void **vertices, int *num_vertices, void **indices,
                            int *num_triangle_indices);
DECLSPEC void OZZ_eval_animation(ozz_t *p, float anim_ratio);
DECLSPEC float OZZ_duration(ozz_t *p);
DECLSPEC size_t OZZ_num_joints(ozz_t *p);
DECLSPEC const short *OZZ_joint_parents(ozz_t *p);
DECLSPEC const float *OZZ_skeleton_matrices(ozz_t *ozz, size_t joint_index); 
DECLSPEC const float *OZZ_model_matrices(ozz_t *ozz, size_t joint_index);
DECLSPEC void OZZ_update_joints(ozz_t *ozz, int num_instances,
                                float abs_time_sec, float *joint_upload_buffer,
                                int max_joints);
DECLSPEC void OZZ_free(void *p);

#ifdef __cplusplus
}  // extern "C"
#endif
