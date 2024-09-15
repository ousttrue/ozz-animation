export type ArticleType = {
  title: string,
  url: string,
};

export type CategoryType = {
  name: string,
  url?: string,
  articles: ArticleType[],
};

export const category: CategoryType = {
  name: "ozz-animation",
  url: "https://guillaumeblanc.github.io/ozz-animation/",
  articles: [
    {
      title: "playback",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/playback/",
    },
    {
      title: "attach",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/attach/",
    },
    {
      title: "blend",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/blend/",
    },
    {
      title: "partial_blend",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/partial_blend/",
    },
    {
      title: "additive",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/additive/",
    },
    {
      title: "baked",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/baked/",
    },
    {
      title: "user_channel",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/user_channel/",
    },
    {
      title: "motion_extraction",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/motion_extraction/",
    },
    {
      title: "motion_playback",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/motion_playback/",
    },
    {
      title: "motion_blend",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/motion_blend/",
    },
    {
      title: "optimize",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/optimize/",
    },
    {
      title: "millipede",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/millipede/",
    },
    {
      title: "two_bone_ik",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/two_bone_ik/",
    },
    {
      title: "look_at",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/look_at/",
    },
    {
      title: "foot_ik",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/foot_ik/",
    },
    {
      title: "skinning",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/skinning/",
    },
    {
      title: "multithread",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/multithread/",
    },
    //
    {
      title: "bvh_player",
      url: "https://ousttrue.github.io/rowmath/",
    },
  ],
}
