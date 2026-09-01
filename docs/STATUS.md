# STATUS

## 현재 상태

- 내부 canvas와 기본 창, 카메라, HUD를 세로 `180×320` 기준으로 전환했다.
- `game/self_test.lua`가 세로 viewport 크기와 `720×1280` 정수 배율 좌표 변환을 검증한다.
- `launch`에서 Space/Enter/위 입력으로 출발하고, `ascending` 중 자동 상승·연료 소모 후 연료 0에서 `returning`으로 전이한다.
- 귀환 거리를 최고 상승 높이로 확정하고 매 100 거리마다 슬롯 기회 1회를 올림 계산한다.
- `returning` 중 초당 45 거리로 자동 하강하고 지구 고도 0에 도착하면 `settlement`로 전이한다.
- 귀환 중 Space/Enter/위 입력으로 슬롯 기회를 1회씩 사용하며, 기회가 0이면 추가 실행되지 않는다.
- 상승 중 발견한 행성 표본은 고도에 따라 가치가 증가하며 미정산 표본 가치로 누적된다.
- 귀환 슬롯은 매 회 `COMET`·`PLANET`·`STAR` 3릴을 뽑고 불일치 `$5`, 같은 심볼 2개 `$15`, 일반 트리플 `$40`, `STAR` 트리플 `$75`의 조합별 잠정 보상을 누적한다.
- 귀환 화면은 최근 3릴 결과, 해당 당첨액과 누적 잠정 슬롯 보상을 표시하며, 안전하게 지구에 도착하면 표본 가치와 슬롯 보상을 한 번만 돈으로 확정한다.
- 정산 뒤 미정산 표본·슬롯 보상과 남은 슬롯 기회는 비워지고 HUD와 메시지에 정산액·보유 돈이 표시된다.
- 정산 상점에서 `F`/아래 입력으로 `$50`을 지불해 연료 탱크를 `+20` 강화할 수 있으며, 돈이 부족하거나 정산 phase가 아니면 구매되지 않는다.
- 정산 뒤 Space/Enter/위 입력으로 재출발하면 고도·원정 최고 고도·슬롯·표본·발견 행성을 초기화하고 강화된 최대 연료를 채워 `ascending`으로 돌아간다.
- engine-hosted 테스트가 연료 강화 구매의 phase/비용 제한과 강화 연료 재출발을 검증한다.
- 상승 중 행성의 표본 탐사 범위보다 가까운 충돌 범위에 진입하면 행성당 한 번 내구도 1을 잃고, HUD에 현재 내구도를 표시한다.
- 내구도 0은 `destroyed`로 전이해 정산 없이 돈·미정산 표본·슬롯 보상·연료 강화를 초기화하고 해당 세션의 개인 최고 높이만 보존한다.
- 파괴 화면에서 Space/Enter/위 입력으로 기본 연료·내구도의 새 원정을 시작할 수 있다.
- engine-hosted 파괴 테스트가 피해 누적, 전체 메타 초기화, 최고 높이 보존과 파괴 후 재시작을 검증한다.
- 실제 LÖVE runtime capture `build/spaceship-runtime-preview.png`는 `540×960`이며 지구·우주선, LAUNCH HUD, 출발 안내와 `DEV PLACEHOLDER` 표기가 세로 화면 안에 보인다.
- 개인 최고 높이는 LÖVE filesystem의 `best-altitude.txt`에 저장하고 새 `PlayScene` 생성 시 복구한다.
- 연료 소진 귀환 전환, 내구도 파괴, 앱 focus 상실과 정상 종료 시 더 높은 기록만 저장하며 메타 초기화는 저장된 최고 높이를 지우지 않는다.
- engine-hosted 저장 테스트가 실제 LÖVE filesystem에서 최초 기본값, 저장 후 새 store/scene 복구, 낮은 기록의 덮어쓰기 방지와 파괴 뒤 기록 보존을 검증한다.
- 정산 상점에서 `H`/오른쪽 입력으로 `$75`를 지불해 최대 내구도를 `+1` 강화할 수 있고, 다음 출발부터 증가한 내구도가 적용된다.
- engine-hosted 상점 테스트가 내구도 강화의 phase/비용 제한, 상점 입력, 강화 내구도 재출발과 파괴 시 내구도 강화 초기화를 검증한다.
- LÖVE touch 좌표를 `180×320` 내부 canvas 좌표로 변환해 scene에 전달하며, 터치로 출발·귀환 슬롯·연료/내구도 구매·재출발·파괴 후 재시작이 가능하다.
- 상승 중 화면 왼쪽/오른쪽을 누르고 있는 동안 해당 방향으로 조종하고, 손가락 이동과 해제도 추적한다. 화면 하단에 phase별 터치 안내를 표시한다.
- engine-hosted 터치 입력 테스트가 터치 출발, hold 조종과 release 정지, 슬롯 실행, 두 상점 구매와 재출발을 검증한다.
- 정산 상점에서 `$125`에 SCOUT 우주선을 구매·선택할 수 있다. SCOUT은 기본 우주선보다 최대 연료가 `+40`, 최대 내구도가 `-1`인 위험/거리 교환 선택지이며 `V` 또는 세로 화면의 우주선 행 터치로 기본 우주선과 전환한다.
- 우주선 구매·선택은 연료/내구도 강화와 함께 다음 출발 능력치에 반영되고, 내구도 0 파괴 시 SCOUT 소유권과 선택 상태도 기본 우주선으로 초기화된다.
- engine-hosted 구매/파괴 테스트가 phase·비용 제한, 중복 구매 방지, 우주선 선택 능력치, 키보드/터치 구매와 파괴 시 소유권·선택 초기화를 검증한다.
- engine-hosted 슬롯 테스트가 주입된 릴 결과로 `STAR` 트리플과 2개 일치 보상, 정산 합산, 재출발 초기화, 파괴 시 슬롯 결과·잠정 보상 초기화와 터치 결과 메시지를 검증한다.
- 안전 귀환 시 표본 수익과 슬롯 수익을 각각 `lastSampleSettlement`·`lastSlotSettlement`로 확정하며, EARTH SHOP에서 총 정산액과 두 수익 내역을 별도로 표시한다.
- engine-hosted 정산 테스트가 두 수익의 합산·정산 중 유지와 재출발/파괴 시 영수증 초기화를 검증한다.
- 행성 충돌 피해는 행성 고도 500마다 1씩 증가하며, 충돌 메시지에 실제 피해량과 남은 내구도를 함께 표시한다.
- engine-hosted 위험도 테스트가 500 고도 피해 경계와 상승 구간 충돌 시 증가한 피해가 실제 scene에 적용되는지 검증한다.
- 상승 중 우주선보다 앞에 보이는 행성 위에 예상 충돌 피해를 `RISK -N`으로 표시하고, 현재 내구도를 모두 소진할 피해는 빨간 `LETHAL -N`으로 구분한다.
- engine-hosted 위험 경고 테스트가 피해량·치명 여부·표시 문구와 귀환 중 경고 비활성화를 검증한다.
- 접근 중인 행성 위에 고도별 예상 표본 가치를 `SAMPLE $N`으로 표시해 충돌 위험과 보상을 함께 비교할 수 있다.
- engine-hosted 접근 경고 테스트가 고도 500·1000에서 표시되는 예상 표본 가치와 문구를 검증한다.
- 상승·귀환 HUD에 `SAMPLES NN  AT RISK $N`을 표시해 현재 원정에서 파괴 시 잃는 미정산 표본 가치를 계속 확인할 수 있다.
- engine-hosted HUD 테스트가 상승과 귀환 양쪽에서 표본 수와 미정산 표본 가치가 함께 표시되는지 검증한다.
- 출발·정산 HUD에 영구 기록을 `PERSONAL BEST NNNN`으로 표시하며, 새 scene이 저장소에서 복구한 기록도 즉시 반영한다.
- engine-hosted HUD 테스트가 출발·정산 phase의 최고 높이 표시와 저장 후 새 scene에서 복구된 표시를 검증한다.
- 출발 화면의 `LAUNCH LOADOUT` 패널이 선택 우주선과 연료·내구도 강화 레벨을 표시하며, 파괴 화면도 메타 초기화 뒤 다음 출발이 `SHIP STARTER`, `FUEL LV.0  HULL LV.0`임을 표시한다.
- engine-hosted loadout 테스트가 기본 장비, SCOUT 선택과 두 강화 구매, 파괴 뒤 기본 우주선·강화 0 초기화의 표시 문자열을 검증한다.
- 실제 LÖVE runtime capture `build/spaceship-runtime-preview.png`에서 `LAUNCH LOADOUT`, `SHIP STARTER`, `FUEL LV.0  HULL LV.0`이 `540×960` 세로 화면 안에 표시되는 것을 확인했다.
- EARTH SHOP에 현재 선택된 우주선 기준의 다음 출발 능력치를 `NEXT <SHIP>`과 `MAX FUEL N  HULL N`으로 항상 표시한다. 연료·내구도 구매, SCOUT 구매·선택, STARTER 재선택 직후 값이 즉시 바뀐다.
- engine-hosted 상점 loadout 테스트가 기본 능력치, 두 강화 구매, SCOUT 선택과 STARTER 재선택에 따른 다음 출발 최대 연료·내구도 갱신을 검증한다.
- EARTH SHOP에 SCOUT의 교환 조건 `SCOUT +40 FUEL / -1 HULL`을 구매 전후 항상 표시해 현재 `NEXT <SHIP>` 및 실제 최대 능력치와 동시에 비교할 수 있다.
- engine-hosted 상점 표시 테스트가 SCOUT 구매 전과 구매·선택 후 모두 교환 조건과 현재 선택 우주선 능력치를 함께 반환하는지 검증한다.
- EARTH SHOP의 우주선 버튼은 구매 전 `BUY SCOUT $125`, 구매 후에는 현재 선택의 반대편인 `SELECT STARTER`/`SELECT SCOUT`를 표시해 누르면 일어날 동작을 정확히 안내한다.
- engine-hosted 입력·표시 테스트가 구매 상태와 양쪽 선택 상태의 버튼 문구, `V` 키와 우주선 행 터치에 따른 선택 전환·메시지·다음 출발 표시 갱신을 검증한다.
- 귀환 슬롯 버튼은 `TAP: SLOT SPIN  N LEFT`로 남은 기회를 표시하고, 모두 사용하면 흐리게 비활성화된 `NO SLOT CHANCES` 상태로 바뀐다.
- engine-hosted 슬롯 버튼 테스트가 남은 기회 표시, 기회 소진 상태와 소진 후 터치가 추가 슬롯을 실행하지 않는 것을 검증한다.
- 귀환 HUD에 현재 고도를 올림한 지구까지 남은 거리 `EARTH IN N`을 표시해 슬롯을 사용할 수 있는 귀환 구간을 즉시 확인할 수 있다.
- engine-hosted HUD 테스트가 `EARTH IN N`이 귀환 중에만 표시되고 상승 중에는 숨겨지는지 검증한다.
- 귀환 HUD에 시작 거리 대비 완료율과 예상 잔여 시간을 `RETURN N%  Ns LEFT`로 함께 표시해 남은 슬롯 플레이 구간을 즉시 비교할 수 있다.
- engine-hosted HUD 테스트가 귀환 고도 변화에 따른 완료율·잔여 시간 갱신과 상승 중 표시 비활성화를 검증한다.
- EARTH SHOP의 연료·내구도·SCOUT 구매 행은 구매 가능하면 초록색 `LEFT $N`으로 구매 후 잔액을 미리 표시하고, 부족하면 빨간색 `SHORT $N`, 구매한 SCOUT은 `OWNED`로 표시한다.
- engine-hosted 상점 표시 테스트가 잔액 `$0`·`$50`·`$200`에서 세 항목의 정확한 구매 후 잔액 또는 부족액을 비교하고 SCOUT 구매 후 `OWNED` 전환을 검증한다.
- EARTH SHOP의 구매 불가 행은 `SHORT $N`으로 현재 잔액에서 실제 부족한 금액을 표시하며, 잔액 변화에 따라 연료·내구도·SCOUT 부족액이 즉시 다시 계산된다.
- engine-hosted 상점 표시 테스트가 잔액 `$0`과 `$50`에서 세 구매 항목의 정확한 부족액 및 연료 항목의 `LEFT $0` 전환을 검증한다.
- EARTH SHOP에서 연료·내구도·SCOUT 구매에 실패하면 정가가 아니라 현재 잔액 기준의 실제 부족액을 `NEED $N MORE` 메시지로 안내한다.
- engine-hosted 입력 메시지 테스트가 잔액 `$20`에서 키보드 연료·내구도 구매와 터치 SCOUT 구매의 정확한 부족액 및 구매 미발생을 검증한다.
- EARTH SHOP에서 연료·내구도·SCOUT 구매에 성공하면 메시지에 지출 후 실제 잔액을 `BALANCE $N`으로 함께 표시한다.
- engine-hosted 입력 메시지 테스트가 키보드 연료·내구도 구매와 터치 SCOUT 구매의 차감된 잔액 및 성공 메시지를 검증한다.
- EARTH SHOP의 연료·내구도 구매 행은 현재 선택 우주선과 강화 상태를 기준으로 구매 후 적용될 다음 출발 능력치를 `MAX N`으로 미리 표시한다.
- engine-hosted 상점 표시 테스트가 STARTER 기본 상태와 연료·내구도 강화 후 선택한 SCOUT 상태에서 구매 후 최대 연료·내구도 미리보기를 검증한다.
- EARTH SHOP의 SCOUT 구매 블록은 구매·선택 시 적용될 대상 우주선과 실제 다음 출발 능력치를 `SCOUT MAX FUEL N  HULL N`으로 직접 표시한다.
- engine-hosted 상점 표시 테스트가 기본 강화와 연료·내구도 1단계 강화 상태에서 SCOUT의 정확한 최대 연료·내구도 미리보기를 검증한다.
- LAUNCH LOADOUT 패널에 선택 우주선과 강화가 반영된 실제 다음 출발 능력치 `MAX FUEL N  HULL N`을 표시한다.
- engine-hosted loadout 테스트가 STARTER 기본 능력치, 강화된 SCOUT 능력치와 파괴 후 초기화된 능력치를 검증한다.
- 실제 LÖVE runtime capture `build/spaceship-runtime-preview.png`에서 `MAX FUEL 100  HULL 3`을 포함한 4줄 launch loadout, `TAP TO LAUNCH`, `DEV PLACEHOLDER`가 겹침이나 잘림 없이 `540×960` 세로 화면 안에 표시되는 것을 확인했다.
- 현재 그래픽은 전부 개발용 Lua placeholder이며 최종 AetherAI 에셋이 아니다.
- 공식 AetherAI 로그인/export가 없으므로 최종 미술은 human-gated pending이다. 코드·상태머신·저장·충돌·슬롯·상점 개발은 계속한다.

## 다음 한 가지

- LAUNCH LOADOUT 패널에 현재 최대 연료 기준의 무충돌 예상 상승 고도와 귀환 슬롯 기회를 표시하고 engine-hosted 계산·표시 테스트를 추가한다.

## 완료 조건

- `make verify LOVE=/Users/jm/.local/bin/love` 통과 (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:24`)
- 세로 실제 런타임 캡처 `540×960`에서 실제 최대 연료·내구도를 포함한 launch loadout, `TAP TO LAUNCH`, `DEV PLACEHOLDER` 표시 확인
- 개인 최고 높이 영구 저장 engine-hosted 자동 테스트 통과
- 출발·정산 HUD의 개인 최고 높이 복구 표시 engine-hosted 자동 테스트 통과
