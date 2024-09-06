const sokol = @import("sokol");
const sg = sokol.gfx;
const shader = @import("bone.glsl.zig");
const rowmath = @import("romath");

const state = struct {
    var pip = sg.Pipeline{};
    var bind = sg.Bindings{};
    var pass_action = sg.PassAction{};
};

// A vertex made of positions and normals.
const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const VertexPNC = struct {
    pos: [3]f32,
    normal: [3]f32,
    color: Color,
};

export fn init() void {
    const kInter: f32 = 0.2;

    // Prepares bone mesh.
    const pos = [6][3]f32{
        .{ 1.0, 0.0, 0.0 },
        .{ kInter, 0.1, 0.1 },
        .{ kInter, 0.1, -0.1 },
        .{ kInter, -0.1, -0.1 },
        .{ kInter, -0.1, 0.1 },
        .{ 0.0, 0.0, 0.0 },
    };

    const ozz::math::Float3 normals[8] = {
        Normalize(Cross(pos[2] - pos[1], pos[2] - pos[0])),
        Normalize(Cross(pos[1] - pos[2], pos[1] - pos[5])),
        Normalize(Cross(pos[3] - pos[2], pos[3] - pos[0])),
        Normalize(Cross(pos[2] - pos[3], pos[2] - pos[5])),
        Normalize(Cross(pos[4] - pos[3], pos[4] - pos[0])),
        Normalize(Cross(pos[3] - pos[4], pos[3] - pos[5])),
        Normalize(Cross(pos[1] - pos[4], pos[1] - pos[0])),
        Normalize(Cross(pos[4] - pos[1], pos[4] - pos[5]))};
    // const Color white = {0xff, 0xff, 0xff, 0xff};
    // const VertexPNC bones[24] = {
    //     {pos[0], normals[0], white}, {pos[2], normals[0], white},
    //     {pos[1], normals[0], white}, {pos[5], normals[1], white},
    //     {pos[1], normals[1], white}, {pos[2], normals[1], white},
    //     {pos[0], normals[2], white}, {pos[3], normals[2], white},
    //     {pos[2], normals[2], white}, {pos[5], normals[3], white},
    //     {pos[2], normals[3], white}, {pos[3], normals[3], white},
    //     {pos[0], normals[4], white}, {pos[4], normals[4], white},
    //     {pos[3], normals[4], white}, {pos[5], normals[5], white},
    //     {pos[3], normals[5], white}, {pos[4], normals[5], white},
    //     {pos[0], normals[6], white}, {pos[1], normals[6], white},
    //     {pos[4], normals[6], white}, {pos[5], normals[7], white},
    //     {pos[4], normals[7], white}, {pos[1], normals[7], white}};

    state.bind.vertex_buffers[0.ATTR_vs_a_position] = sg.makeBuffer(.{
        .data = sg.ATTR_vs_a_color(vertices),
        .label = "triangle-vertices"
    });


    // create shader
    const shd = sg.makeShader(shader.boneShaderDesc(sg.queryBackend()));

    // create pipeline object
    var pip_desc = sg.PipelineDesc{
        .shader = shd,
        .index_type = .UINT16,
        .cull_mode = .BACK,
        .depth = .{
            .write_enabled = true,
            .compare = .LESS_EQUAL,
        },
        .label = "bone-pipeline",
    };
    pip_desc.layout.buffers[0].stride = 28;
    pip_desc.layout.attrs[shader.ATTR_vs_a_position].format = .FLOAT3;
    pip_desc.layout.attrs[shader.ATTR_vs_a_normal].format = .FLOAT3;
    pip_desc.layout.attrs[shader.ATTR_vs_a_color].format = .FLOAT4;
    state.pip = sg.makePipeline(pip_desc);

    //   /* setup resource bindings */
    //   bind = (sg_bindings){.vertex_buffers[0] = vbuf, .index_buffer = ibuf};
    // }
}

export fn draw() void {
    // sg_begin_pass(&(sg_pass){
    //     .action =
    //         {
    //             .colors[0] = {.load_action = SG_LOADACTION_CLEAR,
    //                           .clear_value = {0.25f, 0.5f, 0.75f, 1.0f}},
    //         },
    //     .swapchain = sglue_swapchain()});
    // sg_apply_pipeline(state.pip);
    // sg_apply_bindings(&state.bind);
    // sg_apply_uniforms(SG_SHADERSTAGE_VS, SLOT_vs_params, &SG_RANGE(vs_params));
    // sg_draw(0, 36, 1);
    // __dbgui_draw();
    // sg_end_pass();
}
