struct VSInput {
  float2 inPosition;
}

struct VSOutput {
  float4 pos : SV_Position;
  float2 npos;
};

struct PushConstants {
  uint64_t orbitBufferAddress;
  uint32_t orbitLength;
  float    scale;
  uint16_t maxIter;
  half     ar;
};

[[vk::push_constant]] PushConstants pc;

float2 getReferenceCenter() {
  double* orbit = (double*)pc.orbitBufferAddress;
  return float2(float(orbit[0]), float(orbit[1]));
}

float2 getOrbitPoint(uint i) {
  double* orbit = (double*)pc.orbitBufferAddress;
  return float2(float(orbit[(i + 1) * 2]), float(orbit[(i + 1) * 2 + 1]));
}

float mandelbrotIterations(float2 delta0) {
  float2 delta = delta0;

  for (uint i = 0; i < pc.orbitLength - 1 && i < pc.maxIter; ++i) {
    float2 X = getOrbitPoint(i);

    // complex multiplication: delta *= (2*X + delta)
    float2 temp = float2(2.0 * X.x, 2.0 * X.y) + delta;
    float2 newDelta = float2(
      delta.x * temp.x - delta.y * temp.y,
      delta.x * temp.y + delta.y * temp.x
    );

    // add delta0
    delta = newDelta + delta0;
    
    // check escape: |X_{n+1} + delta_{n+1}|^2 > 256
    float2 X_next = getOrbitPoint(i + 1);
    float2 Y = X_next + delta;
    float mag2 = Y.x * Y.x + Y.y * Y.y;
    
    if (mag2 > 256.0) {
      float log_zn = log(mag2) / 2.0;
      float nu = log(log_zn / log(16.0)) / log(2.0);
      return float(i + 1) + 1.0 - nu;
    }
  }
  
  return float(pc.maxIter);
}

float3 colorCode(float iterations) {
  if (iterations >= pc.maxIter) {
    return float3(1.0, 1.0, 1.0); // Inside the set = white
  }

  // Smooth coloring using continuous iteration count
  float t = iterations / pc.maxIter;

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
  float2 refc = getReferenceCenter();
  float2 pt = float2(
     vertIn.npos.x          * 1.5 * pow(10.0, pc.scale) + refc.x,
    (vertIn.npos.y / pc.ar) * 1.5 * pow(10.0, pc.scale) + refc.y,
  );
  float3 color = colorCode(mandelbrotIterations(pt));

  return float4(color, 1.0); // rgb + alpha
}
