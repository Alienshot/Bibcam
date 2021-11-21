// Bibcam format configuration
static const uint2 BibcamFrameSize = uint2(1920, 1080);

// Hue encoding
float3 Hue2RGB(float hue)
{
    float h = hue * 6 - 2;
    float r = abs(h - 1) - 1;
    float g = 2 - abs(h);
    float b = 2 - abs(h - 2);
    return saturate(float3(r, g, b));
}

// Hue value calculation
float RGB2Hue(float3 c)
{
    float minc = min(min(c.r, c.g), c.b);
    float maxc = max(max(c.r, c.g), c.b);
    float div = 1 / (6 * max(maxc - minc, 1e-5));
    float r = (c.g - c.b) * div;
    float g = 1.0 / 3 + (c.b - c.r) * div;
    float b = 2.0 / 3 + (c.r - c.g) * div;
    return frac(lerp(r, lerp(g, b, c.g < c.b), c.r < max(c.g, c.b)) + 1);
}

// yCbCr decoding
float3 YCbCrToSRGB(float y, float2 cbcr)
{
    float b = y + cbcr.x * 1.772 - 0.886;
    float r = y + cbcr.y * 1.402 - 0.701;
    float g = y + dot(cbcr, float2(-0.3441, -0.7141)) + 0.5291;
    return float3(r, g, b);
}

// Metadata encoding
bool EncodeMetadata(in float4x4 data, float2 uv)
{
    uint2 p = uv * BibcamFrameSize + 0.5 / BibcamFrameSize;
    uint dw = asint(data[(p.x / 8) & 3][p.x / (8 * 4)]);
    bool mask = (p.y < 8 * 32) && (p.x < 8 * 16);
    return (dw >> (p.y / 8)) & mask;
}

//
// Depth hue encoding
//

static const float DepthHueMargin = 0.01;
static const float DepthHuePadding = 0.01;

float3 EncodeDepth(float depth, float2 range)
{
    // Depth range
    depth = (depth - range.x) / (range.y - range.x);
    // Padding
    depth = depth * (1 - DepthHuePadding * 2) + DepthHuePadding;
    // Margin
    depth = saturate(depth) * (1 - DepthHueMargin * 2) + DepthHueMargin;
    // Hue encoding
    return Hue2RGB(depth);
}

float DecodeDepth(float3 rgb, float2 range)
{
    // Hue decoding
    float depth = RGB2Hue(rgb);
    // Padding/margin
    const float ext = DepthHueMargin + DepthHuePadding;
    depth = depth * (1 + ext * 2) - ext;
    // Depth range
    return lerp(range.x, range.y, depth);
}

//
// UV coordinate remapping functions
//
// +-----+-----+  C: Color
// |  Z  |     |  Z: Hue-encoded depth
// +-----+  C  |  S: Human stencil
// | S/M |     |  M: Metadata
// +-----+-----+
//

float2 UV_FullToStencil(float2 uv)
{
    return uv * 2;
}

float2 UV_FullToDepth(float2 uv)
{
    uv *= 2;
    uv.y -= 1;
    return uv;
}

float2 UV_FullToColor(float2 uv)
{
    uv.x = uv.x * 2 - 1;
    return uv;
}

float2 UV_StencilToFull(float2 uv)
{
    return uv * 0.5;
}

float2 UV_DepthToFull(float2 uv)
{
    return uv * 0.5 + float2(0, 0.5);
}

float2 UV_ColorToFull(float2 uv)
{
    uv.x = lerp(0.5, 1, uv.x);
    return uv;
}

// Multiplexer

float3 BibcamMux(float2 uv, float m, float3 c, float3 z, float s)
{
    return uv.x > 0.5 ? c : (uv.y > 0.5 ? z : float3(s, 0, m));
}
