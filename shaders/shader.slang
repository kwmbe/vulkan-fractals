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

// represent a complex number as val * 2^exp
// val is a float2 kept near [-2, 2] by normalization
struct FE2 {
  float2 val;
  int    exp;
};

[[vk::push_constant]] PushConstants pc;

float2 getOrbitPoint(float* orbit, uint i) {
  return float2(orbit[(i + 1) * 2], orbit[(i + 1) * 2 + 1]);
}

// complex multiply: FE2 * float2 (used for 2*Zn, which is 0(1))
FE2 fe2_mul_f2(FE2 a, float2 b) {
  return { float2(a.val.x * b.x - a.val.y * b.y, 
                  a.val.x * b.y + a.val.y * b.x), a.exp};
}

// complex multiply: FE2 * FE2 (used for the dz^2 term)
FE2 fe2_mul(FE2 a, FE2 b) {
  return { float2(a.val.x * b.val.x - a.val.y * b.val.y,
                  a.val.x * b.val.y + a.val.y * b.val.x), a.exp + b.exp };
}

// complex add: FE2 + FE2
// Terms more than 25 bits apart are sub-ULP and dropped automatically
FE2 fe2_add(FE2 a, FE2 b) {
  int d = a.exp - b.exp;

  if (d > 25) return a;
  if (d < -25) return b;

  return { a.val + b.val * exp2(float(-d)), a.exp };
}

// renormalize: prevent val drifting toward overflow
// Uses bit-level exponent extraction to avoid frexp's out-parameter
FE2 fe2_normalize(FE2 a) {
  float m = max(abs(a.val.x), abs(a.val.y));
  if (m == 0.0f) return a;
  int e = int((asuint(m) >> 23) & 0xFF) - 127;

  return { a.val * exp2(float(-e)), a.exp + e };
}

// convert back to float2. Only call when dz.exp >= -100 (near 0(1))
float2 fe2_to_float2(FE2 a) {
  return a.val * exp2(float(a.exp));
}

float mandelbrotIterations(float2 npos) {
  float* orbit = (float*) pc.orbitBufferAddress;

  // build dc as FE2
  // dc_actual = npos * 1.5 * 10^scale = npos * 1.5 * 2^(scale * log2(10))
  // split the base-2 exponent into integer (dc.exp) + fractional (dc.scale)

  float scale_bits = pc.scale * 3.32192809f; // scale * log2(10)
  int   dc_exp     = int(floor(scale_bits));
  float dc_scale   = exp2(scale_bits - float(dc_exp)); // 2^frac in [1, 2]

  FE2 dc = { float2(npos.x, npos.y / pc.ar) * 1.5f * dc_scale, dc_exp };
  FE2 dz = { float2(0.0f, 0.0f), dc_exp};

  float2 dz_plain = float2(0.0f, 0.0f);
  bool   rebased = false;

  float2 dc_f = fe2_to_float2(dc);
  float Cr = orbit[0] + dc_f.x;
  float Ci = orbit[1] + dc_f.y;

  for (uint i = 0; i < pc.orbitLength - 1 && i < pc.maxIter; ++i) {
    if (!rebased) {
      float2 Zn  = getOrbitPoint(orbit, i);
      float2 Zn1 = getOrbitPoint(orbit, i + 1);

      // dz_{n+1} = 2*Zn*dz + dz^2 + dc
      // The dz^2 term has exponent 2*dz.exp => dc.exp is dropped
      // automatically by fe2_add when it falls below 25-bit threshold
      FE2 term1 = fe2_mul_f2(dz, 2.0f * Zn); // 2 * Zn * dz
      FE2 term2 = fe2_mul(dz, dz);           // dz^2
      dz = fe2_add(fe2_add(term1, term2), dc);

      // renormalize every 16 iterations to keep val in range
      if ((i & 15u) == 15u) dz = fe2_normalize(dz);

      // Skip escape/rebase checks while dz is still tiny (exp < -100),
      // since fe2_to_float2 would just return ~0 and Y would equal Zn1
      if (dz.exp >= -100) {
        float2 dz_f   = fe2_to_float2(dz);
        float2 Y      = Zn1 + dz_f;
        float  mag2   = dot(Y, Y);
        float  dzmag2 = dot(dz_f, dz_f);

        if (isinf(mag2) || isnan(mag2)) return float(i + 1u);

        if (dzmag2 > mag2) {
          dz_plain = Y;
          rebased = true;
          continue;
        }
        if (mag2 > 65536.0f) {
          float log_zn = log(mag2) * 0.5f;
          float nu = log(log_zn / log(2.0f)) / log(2.0f);
          return float(i + 1) + 1.0f - nu;
        }
      }
    } else {
      // post-rebase: plain mandebrot
      // dc is sub-float-precision relative to C at deep zoom, so c = C

      float2 newdz = float2(
        dz_plain.x * dz_plain.x - dz_plain.y * dz_plain.y + Cr,
        2.0f * dz_plain.x * dz_plain.y + Ci
      );
      dz_plain = newdz;
      
      float mag2 = dot(dz_plain, dz_plain);

      if (mag2 > 65536.0f) {
        float log_zn = log(mag2) * 0.5f;
        float nu = log(log_zn / log(2.0f)) / log(2.0f);
        return float(i + 1) + 1.0f - nu;
      }
    }
  }
  return float(pc.maxIter);
}

float3 colorCode(float iterations) {
  if (iterations >= float(pc.maxIter)) {
    return float3(0.0, 0.0, 0.0); // Inside the set = black
  }

  // Smooth coloring using continuous iteration count
  float t = iterations / float(pc.maxIter);

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
  return float4(colorCode(mandelbrotIterations(vertIn.npos)), 1.0);
}
