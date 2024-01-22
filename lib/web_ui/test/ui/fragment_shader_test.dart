// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;
import 'package:web_engine_tester/golden_tester.dart';

import '../common/fake_asset_manager.dart';
import '../common/test_initialization.dart';
import 'utils.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

// This fragment shader generates some voronoi noise. It uses a pseudo-random
// number generator implemented in the shader itself, so its output is
// deterministic.
const String kVoronoiShaderSksl = r'''
{
  "sksl": "// This SkSL shader is autogenerated by spirv-cross.\n\nfloat4 flutter_FragCoord;\n\nuniform float uTileSize;\n\nvec4 fragColor;\n\nvec2 FLT_flutter_local_FlutterFragCoord()\n{\n    return flutter_FragCoord.xy;\n}\n\nfloat FLT_flutter_local_rand(vec2 co)\n{\n    return fract(sin(dot(co, vec2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);\n}\n\nvec2 FLT_flutter_local_fuzzGridPoint(vec2 coordinate)\n{\n    vec2 param = coordinate * 400.0;\n    vec2 param_1 = coordinate * 400.0;\n    return coordinate + vec2((FLT_flutter_local_rand(param) - 0.5) * 0.800000011920928955078125, (FLT_flutter_local_rand(param_1) - 0.5) * 0.800000011920928955078125);\n}\n\nvec3 FLT_flutter_local_getColorForGridPoint(vec2 coordinate)\n{\n    vec2 param = coordinate * 100.0;\n    vec2 param_1 = coordinate * 200.0;\n    vec2 param_2 = coordinate * 300.0;\n    return vec3(FLT_flutter_local_rand(param), FLT_flutter_local_rand(param_1), FLT_flutter_local_rand(param_2));\n}\n\nvoid FLT_main()\n{\n    vec2 uv = FLT_flutter_local_FlutterFragCoord() / vec2(uTileSize);\n    vec2 upperLeft = floor(uv);\n    vec2 upperRight = vec2(ceil(uv.x), floor(uv.y));\n    vec2 bottomLeft = vec2(floor(uv.x), ceil(uv.y));\n    vec2 bottomRight = ceil(uv);\n    vec2 closestPoint = upperLeft;\n    vec2 param_3 = upperLeft;\n    float dist = distance(uv, FLT_flutter_local_fuzzGridPoint(param_3));\n    vec2 param_4 = upperRight;\n    float upperRightDistance = distance(uv, FLT_flutter_local_fuzzGridPoint(param_4));\n    if (upperRightDistance < dist)\n    {\n        dist = upperRightDistance;\n        closestPoint = upperRight;\n    }\n    vec2 param_5 = bottomLeft;\n    float bottomLeftDistance = distance(uv, FLT_flutter_local_fuzzGridPoint(param_5));\n    if (bottomLeftDistance < dist)\n    {\n        dist = bottomLeftDistance;\n        closestPoint = bottomLeft;\n    }\n    vec2 param_6 = bottomRight;\n    float bottomRightDistance = distance(uv, FLT_flutter_local_fuzzGridPoint(param_6));\n    if (bottomRightDistance < dist)\n    {\n        dist = bottomRightDistance;\n        closestPoint = bottomRight;\n    }\n    vec2 param_7 = closestPoint;\n    fragColor = vec4(FLT_flutter_local_getColorForGridPoint(param_7), 1.0);\n}\n\nhalf4 main(float2 iFragCoord)\n{\n      flutter_FragCoord = float4(iFragCoord, 0, 0);\n      FLT_main();\n      return fragColor;\n}\n",
  "stage": 1,
  "target_platform": 2,
  "uniforms": [
    {
      "array_elements": 0,
      "bit_width": 32,
      "columns": 1,
      "location": 0,
      "name": "uTileSize",
      "rows": 1,
      "type": 10
    }
  ]
}
''';

Future<void> testMain() async {
  setUpUnitTests(
    withImplicitView: true,
    setUpTestViewDimensions: false,
  );

  const ui.Rect region = ui.Rect.fromLTWH(0, 0, 300, 300);

  late FakeAssetScope assetScope;
  setUp(() {
    assetScope = fakeAssetManager.pushAssetScope();
    assetScope.setAsset(
      'voronoi_shader',
      ByteData.sublistView(utf8.encode(kVoronoiShaderSksl))
    );
  });

  tearDown(() {
    fakeAssetManager.popAssetScope(assetScope);
  });

  test('fragment shader', () async {
    final ui.FragmentProgram program = await renderer.createFragmentProgram('voronoi_shader');
    final ui.FragmentShader shader = program.fragmentShader();

    Future<void> drawCircle(String goldenFilename) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder, region);
      canvas.drawCircle(const ui.Offset(150, 150), 100, ui.Paint()..shader = shader);

      await drawPictureUsingCurrentRenderer(recorder.endRecording());

      await matchGoldenFile(goldenFilename, region: region);
    }

    shader.setFloat(0, 10.0);
    await drawCircle('fragment_shader_voronoi_tile10px.png');

    // Make sure we can reuse the shader object with a new uniform value.
    shader.setFloat(0, 25.0);
    await drawCircle('fragment_shader_voronoi_tile25px.png');
  }, skip: isHtml); // Fragment shaders are not supported by the HTML renderer.
}
