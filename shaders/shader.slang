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
  return 1;
}

[shader("vertex")]
VSOutput vertMain(VSInput input) {
  VSOutput output;
  output.pos = float4(input.inPosition, 0.0, 1.0);
  output.npos = float2((input.inPosition.x + 1) * 0.5, (input.inPosition.y + 1) * 0.5);
  return output;
}

[shader("fragment")]
float4 fragMain(VSOutput vertIn) : SV_Target {
  float3 color;
  float2 uv = vertIn.npos;



  return float4(uv, 1.0, 1.0); // rgb + alpha
}
