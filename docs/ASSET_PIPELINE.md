# 사진 기반 Asset Studio 고품질 픽셀 변환

이 문서는 에셋 생성의 최신 공통 baseline이며, 그중 **새로 사진에서 파생하는 raster 에셋**에 적용할 구속력 있는 변환 표준이다. **구매·라이선스된 픽셀 아트 팩이 항상 1순위**이며, 적합한 팩 에셋이 없고 프로젝트 규칙이 사진 사용을 허용할 때 이 워크플로를 사용한다. 과거 문서의 AetherAI-only, SpriteCook-only 같은 provider-only 문구는 사진에 적합한 신규 raster 에셋에 대해 승인된 Asset Studio 경로를 금지하지 않는다. 다만 사람/캐릭터 identity lock, 장면 승인 게이트, 사진 사용과 genuinely incompatible한 도메인 규칙은 그대로 유지한다.

## 표준 단계

아래 단계를 순서대로 수행하고 provenance와 QA 근거를 함께 보존한다.

1. 직접 소유·라이선스했거나 provenance를 기록한 실제 사진을 준비한다.
2. Asset Studio의 high-quality image-to-image로 사진을 픽셀 아트로 재해석한다.
3. 배경을 제거한다.
4. 대상 런타임 셀 크기로 resize한다.
5. 프로젝트의 제한 팔레트로 quantization한다.
6. 투명 alpha, 셀 alignment, nearest-neighbor 표시를 실제 런타임 크기에서 QA한다.

공식 워크플로 이름의 “Asset Studio 고품질 픽셀 변환”은 처리 절차를 뜻한다. **PixelPerfect 엔진 또는 그와 같은 이름의 런타임 엔진을 사용한다는 뜻이 아니다.**

## 출처와 우선순위

- 구매·라이선스 팩에서 목적에 맞는 에셋을 먼저 찾고 재사용한다.
- 웹 사진은 재사용이 명시적으로 허용된 것만 사용할 수 있다. 원본 URL, author, license, 다운로드한 원본의 hash를 기록한다. 출처나 재사용 허가가 불명확하면 사용하지 않는다.
- 각 변환본에는 원본 사진 기록, Asset Studio 설정/출력 식별자, 파생 단계, 최종 파일 hash를 연결한다.
- 프로젝트별 source/identity 규칙이 더 엄격하면 그 규칙이 이 공통 표준보다 우선한다. 특히 사용자가 직접 제공하기로 한 함선·지구·행성 등은 프로젝트의 기존 규칙 없이는 사진 변환으로 대체하지 않는다.
- 최종 적용 에셋은 같은 커밋에서 프로젝트 manifest/provenance와 `docs/GENERATED_ASSET_LOG.md`에 기록한다.
