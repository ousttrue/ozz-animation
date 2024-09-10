export type ArticleType = {
  title: string,
  url: string,
  samples: string[],
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
      samples: [
      ],
    },
    {
      title: "attach",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/attach/",
      samples: [
      ],
    },
    {
      title: "blend",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/blend/",
      samples: [
      ],
    },
    {
      title: "partial_blend",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/partial_blend/",
      samples: [
      ],
    },
    {
      title: "additive",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/additive/",
      samples: [
      ],
    },
    {
      title: "baked",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/baked/",
      samples: [
      ],
    },
    {
      title: "user_channel",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/user_channel/",
      samples: [
      ],
    },
    {
      title: "motion_extraction",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/motion_extraction/",
      samples: [
      ],
    },
    {
      title: "motion_playback",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/motion_playback/",
      samples: [
      ],
    },
    {
      title: "motion_blend",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/motion_blend/",
      samples: [
      ],
    },
    {
      title: "optimize",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/optimize/",
      samples: [
      ],
    },
    {
      title: "millipede",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/millipede/",
      samples: [
      ],
    },
    {
      title: "two_bone_ik",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/two_bone_ik/",
      samples: [
      ],
    },
    {
      title: "look_at",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/look_at/",
      samples: [
      ],
    },
    {
      title: "foot_ik",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/foot_ik/",
      samples: [
      ],
    },
    {
      title: "skinning",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/skinning/",
      samples: [
      ],
    },
    {
      title: "multithread",
      url: "https://guillaumeblanc.github.io/ozz-animation/samples/multithread/",
      samples: [
      ],
    },
  ],
}
