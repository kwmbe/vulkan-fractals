static const int MAX_ITER = 100;

struct VSInput {
  float2 inPosition;
  float3 inColor;
}

struct VSOutput {
  float4 pos : SV_Position;
  float2 npos;
};

float mandelbrotIterations(float2 c) {
  float2 z = float2(0.0, 0.0);

  for (int i = 0; i < MAX_ITER; i++) {
    // z = z^2 + c
    float zx = z.x * z.x - z.y * z.y + c.x;
    float zy = 2.0 * z.x * z.y + c.y;
    z = float2(zx, zy);

    // Check if escaped (magnitude > 2)
    float mag2 = z.x * z.x + z.y * z.y;
    if (mag2 > 4.0) {
      // Smooth iteration count for continuous coloring
      float log_zn = log(mag2) / 2.0;
      float nu = log(log_zn / log(2.0)) / log(2.0);
      return i + 1.0 - nu;
    }
  }

  return MAX_ITER;
}

float3 colorCode(float iterations) {
  if (iterations >= MAX_ITER) {
    return float3(1.0, 1.0, 1.0); // Inside the set = white
  }

  // Smooth coloring using continuous iteration count
  float t = iterations / MAX_ITER;

  // Create a colorful gradient
  float3 color;

  // Use sine waves for smooth color transitions
  color.r = 0.5 + 0.5 * sin(3.0 + t * 6.28318 + 0.0);
  color.g = 0.5 + 0.5 * sin(3.0 + t * 6.28318 + 2.09439);
  color.b = 0.5 + 0.5 * sin(3.0 + t * 6.28318 + 4.18879);

  return color;
}

[shader("vertex")]
VSOutput vertMain(VSInput input) {
  VSOutput output;
  output.pos = float4(input.inPosition, 0.0, 1.0);
  output.npos = input.inPosition;
  return output;
}

[shader("fragment")]
float4 fragMain(VSOutput vertIn) : SV_Target {
  float2 pt = float2(vertIn.npos.x * 1.5 - 0.5, vertIn.npos.y * 1.2);
  float3 color = colorCode(mandelbrotIterations(pt));

  return float4(color, 1.0); // rgb + alpha
}
