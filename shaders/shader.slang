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

double2 getOrbitPoint(double* orbit, uint i) {
  return double2(orbit[(i + 1) * 2], orbit[(i + 1) * 2 + 1]);
}

float mandelbrotIterations(float2 delta0_f) {
  double* orbit = (double*)pc.orbitBufferAddress;

  double2 dc = double2(double(delta0_f.x), double(delta0_f.y));
  double2 dz = double2(0.0, 0.0);
  bool rebased = false;

  for (uint i = 0; i < pc.orbitLength - 1 && i < uint(pc.maxIter); ++i) {
    if (!rebased) {
      double2 Zn  = getOrbitPoint(orbit, i);
      double2 Zn1 = getOrbitPoint(orbit, i + 1);

      double2 temp = double2(2.0 * Zn.x + dz.x, 2.0 * Zn.y + dz.y);
      dz = double2(
        dz.x * temp.x - dz.y * temp.y + dc.x,
        dz.x * temp.y + dz.y * temp.x + dc.y
      );

      double2 Y = double2(Zn1.x + dz.x, Zn1.y + dz.y);
      double mag2 = Y.x * Y.x + Y.y * Y.y;

      double dzmag2 = dz.x * dz.x + dz.y * dz.y;
      if (dzmag2 > mag2) {
        // dz becomes the full pixel value; switch to plain iteration
        dz = Y;
        rebased = true;
      }

      if (mag2 > 65536.0) {
        float log_zn = log(float(mag2)) * 0.5;
        float nu = log(log_zn / log(2.0)) / log(2.0);
        return float(i + 1) + 1.0 - nu;
      }
    } else {
      // Plain Mandelbrot: z_{n+1} = z_n² + c
      // c = C + dc, but C is baked into dz already after rebase
      // We need the full c: read C from orbit buffer prefix
      double Cr = orbit[0];
      double Ci = orbit[1];
      double2 c_full = double2(Cr + dc.x, Ci + dc.y);

      double2 newdz = double2(
        dz.x * dz.x - dz.y * dz.y + c_full.x,
        2.0 * dz.x * dz.y         + c_full.y
      );
      dz = newdz;

      double mag2 = dz.x * dz.x + dz.y * dz.y;
      if (mag2 > 65536.0) {
        float log_zn = log(float(mag2)) * 0.5;
        float nu = log(log_zn / log(2.0)) / log(2.0);
        return float(i + 1) + 1.0 - nu;
      }
    }
  }

  return float(pc.maxIter);
}

float3 colorCode(float iterations) {
  if (iterations >= pc.maxIter) {
    return float3(0.0, 0.0, 0.0); // Inside the set = black
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
  output.pos  = float4(input.inPosition, 0.0, 1.0);
  output.npos = input.inPosition;
  return output;
}

[shader("fragment")]
float4 fragMain(VSOutput vertIn) : SV_Target {
  float2 delta0 = float2(
     vertIn.npos.x          * 1.5 * pow(10.0, pc.scale),
    (vertIn.npos.y / pc.ar) * 1.5 * pow(10.0, pc.scale)
  );
  return float4(colorCode(mandelbrotIterations(delta0)), 1.0);
}
