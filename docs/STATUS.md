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
- LAUNCH LOADOUT에 현재 최대 연료·연료 소모율·상승 속도로 계산한 무충돌 예상 고도와 그 귀환 거리의 슬롯 기회를 `NO-HIT N  SLOTS N`으로 표시한다.
- engine-hosted loadout 테스트가 기본 STARTER의 `NO-HIT 600  SLOTS 6`과 연료 강화 SCOUT의 `NO-HIT 960  SLOTS 10` 계산·표시를 검증한다.
- 실제 LÖVE runtime capture `build/spaceship-runtime-preview.png`는 `540×960`이며 5줄 launch loadout의 `NO-HIT 600  SLOTS 6`, `TAP TO LAUNCH`, `DEV PLACEHOLDER`가 줄바꿈·겹침·잘림 없이 표시된다.
- EARTH SHOP의 현재 선택 우주선 능력치 아래에 무충돌 예상 상승 고도와 슬롯 기회를 `NO-HIT N  SLOTS N`으로 표시한다.
- engine-hosted 상점 loadout 테스트가 기본 STARTER의 `NO-HIT 600  SLOTS 6`, 연료 강화 직후의 `NO-HIT 720  SLOTS 8`, SCOUT 선택 직후의 `NO-HIT 960  SLOTS 10` 갱신을 검증한다.
- EARTH SHOP의 SCOUT 구매·선택 블록에도 대상 우주선의 무충돌 예상 상승 고도와 슬롯 기회를 표시한다. 기본 상태의 SCOUT 미리보기는 `NO-HIT 840  SLOTS 9`이며 연료 강화 직후 `NO-HIT 960  SLOTS 10`으로 갱신되고, SCOUT 선택 상태에서는 대상 STARTER의 `NO-HIT 720  SLOTS 8`을 표시한다. 추가 행에 맞춰 상점 패널과 하단 재출발 터치 영역도 확장했다.
- engine-hosted 상점 미리보기 테스트가 구매 전 SCOUT 예측, 연료 강화 직후 갱신과 SCOUT 선택 시 STARTER 대상 전환을 검증한다.
- EARTH SHOP의 연료 강화 구매 행 바로 아래에 구매 후 무충돌 예상 상승 고도와 슬롯 기회를 표시한다. 기본 STARTER는 `NO-HIT 720  SLOTS 8`, 강화 1단계 STARTER는 다음 구매 시 `NO-HIT 840  SLOTS 9`, 같은 강화의 SCOUT은 `NO-HIT 1080  SLOTS 11`로 즉시 갱신된다.
- engine-hosted 상점 테스트가 연료 강화 전후와 STARTER/SCOUT 선택 변경 직후의 구매 후 예측값을 검증한다. 추가 예측 행과 일치하도록 정산 내역·상점 행 배치 및 터치 영역을 조정했다.
- EARTH SHOP에서 연료 강화를 구매하면 성공 메시지에 갱신된 최대 연료와 함께 무충돌 예상 상승 고도·슬롯 기회 및 남은 잔액을 표시한다. 기본 STARTER 1단계는 `NO-HIT 720  SLOTS 8`, SCOUT 1단계는 `NO-HIT 960  SLOTS 10`으로 즉시 안내한다.
- engine-hosted 입력 테스트가 STARTER와 SCOUT 각각의 연료 강화 직후 실제 선택 우주선 기준 예측값과 잔액이 성공 메시지에 표시되는지 검증한다.
- EARTH SHOP에서 SCOUT을 구매·선택하면 성공 메시지에 선택된 SCOUT의 실제 최대 연료·내구도와 무충돌 예상 상승 고도·슬롯 기회를 표시한다. engine-hosted 입력 테스트가 연료·내구도 강화 1단계 상태의 `MAX FUEL 160  HULL 3`, `NO-HIT 960  SLOTS 10`과 구매 후 잔액을 검증한다.
- EARTH SHOP에서 이미 보유한 STARTER/SCOUT을 전환하면 성공 메시지에 새로 선택한 우주선의 무충돌 예상 상승 고도와 슬롯 기회를 즉시 표시한다. engine-hosted 입력 테스트가 키보드 STARTER 선택의 `NO-HIT 720  SLOTS 8`과 터치 SCOUT 선택의 `NO-HIT 960  SLOTS 10`을 검증한다.
- EARTH SHOP에서 이미 보유한 STARTER/SCOUT을 전환하면 성공 메시지에 새 우주선의 실제 최대 연료·내구도도 함께 표시한다. engine-hosted 입력 테스트가 키보드 STARTER 선택의 `MAX FUEL 120  HULL 4`와 터치 SCOUT 선택의 `MAX FUEL 160  HULL 3`을 각각의 무충돌 예측과 함께 검증한다.
- EARTH SHOP에서 내구도 강화를 구매하면 성공 메시지에 선택 우주선의 실제 최대 연료·내구도, 무충돌 예상 상승 고도·슬롯 기회와 남은 잔액을 함께 표시한다. engine-hosted 입력 테스트가 강화된 STARTER의 `MAX FUEL 120  HULL 4`, `NO-HIT 720  SLOTS 8`과 SCOUT의 `MAX FUEL 140  HULL 3`, `NO-HIT 840  SLOTS 9`를 검증한다.
- EARTH SHOP의 내구도 강화 구매 행 아래에 구매 후 선택 우주선의 실제 `MAX FUEL N  HULL N`과 `NO-HIT N  SLOTS N`을 표시한다. 연료 강화와 우주선 선택 변경 직후에도 미리보기가 즉시 갱신되며, 추가 두 행에 맞춰 상점 배치와 터치 영역을 조정했다.
- engine-hosted 상점 표시 테스트가 기본 STARTER의 `MAX FUEL 100  HULL 4`, `NO-HIT 600  SLOTS 6`, 연료 강화 STARTER의 `MAX FUEL 120  HULL 4`, `NO-HIT 720  SLOTS 8`, 강화된 SCOUT의 `MAX FUEL 160  HULL 4`, `NO-HIT 960  SLOTS 10` 미리보기를 검증한다.
- EARTH SHOP의 연료·내구도 구매 행은 `FUEL LV.0>1`·`HULL LV.0>1` 형식으로 현재 강화 레벨과 구매 후 레벨을 표시하며, 반복 구매 뒤에는 각각 `LV.1>2`로 즉시 갱신된다.
- engine-hosted 상점 표시 테스트가 기본 레벨, 연료만 구매한 상태, 두 강화를 구매한 상태와 SCOUT 선택 상태에서 두 구매 행의 현재·구매 후 레벨을 검증한다.
- 연료·내구도 강화 구매 성공 메시지는 적용된 강화 레벨을 `LV.n`으로 표시해 상점 행의 갱신된 레벨과 바로 대조할 수 있다.
- engine-hosted 입력 테스트가 STARTER와 SCOUT의 1단계 강화 메시지 및 반복 구매 뒤 연료·내구도 2단계 메시지를 검증한다.
- EARTH SHOP의 `NEXT <SHIP>` 능력치 블록에 현재 `FUEL LV.n  HULL LV.n`을 표시해 구매 행·성공 메시지·다음 출발 loadout의 강화 상태를 한눈에 대조할 수 있다. 추가 행이 세로 화면 안에 들어오도록 상점 패널 내용을 위로 확장했다.
- engine-hosted 상점 표시 테스트가 기본 강화 0, 연료만 1단계, 두 강화 1단계와 STARTER/SCOUT 선택 전환 뒤의 현재 강화 레벨 표시를 검증한다.
- 자동 귀환 중에도 아직 충돌하지 않은 행성과 실제 충돌하면 고도별 피해가 내구도에 적용된다. 내구도 0이면 귀환에 실패해 잠정 표본·슬롯 보상, 돈, 구매 우주선과 강화를 모두 초기화하고 개인 최고 높이만 보존한다.
- engine-hosted scene 테스트가 강화·SCOUT 구매와 잠정 슬롯 보상이 있는 귀환 상태에서 행성 충돌로 파괴될 때 전체 메타 초기화, 슬롯 결과 삭제, 최고 높이 보존과 파괴 메시지를 검증한다.
- 자동 귀환 중 우주선 아래에서 접근하는 미충돌 행성에도 예상 피해를 `RISK -N`, 현재 내구도를 모두 소진할 피해를 `LETHAL -N`으로 표시한다. 귀환 중에는 획득할 수 없는 표본 가치 안내를 숨긴다.
- engine-hosted 표시 테스트가 귀환 방향의 일반·치명 경고, 반대 방향과 이미 충돌한 행성의 경고 비활성화, 표본 가치 안내 비활성화를 검증한다.
- 자동 귀환 중에도 키보드 또는 화면 하단의 `LEFT`·`RIGHT` hold 입력으로 좌우 조종해 접근 행성을 회피할 수 있다.
- 귀환 터치 행을 `LEFT`·`SPIN N`·`RIGHT` 세 버튼으로 분리해 조종 터치가 슬롯을 소비하지 않고 슬롯 터치가 우주선을 움직이지 않게 했다. 슬롯 소진 시 가운데 버튼은 `NO SLOTS`로 비활성화된다.
- engine-hosted 입력 테스트가 귀환 좌우 hold/release 조종, 조종·슬롯 영역 분리, 슬롯 기회 소진과 실제 귀환 경로의 행성 회피를 검증한다.
- 귀환 중 누르고 있는 `LEFT`·`RIGHT` 조종 버튼은 밝은 청록색 배경과 어두운 글자로 강조되어 현재 입력 방향을 즉시 표시한다. 키보드와 터치가 실제 이동 및 같은 표시 상태를 공유한다.
- engine-hosted 표시 상태 테스트가 귀환 조종 버튼의 기본 상태, 왼쪽 터치 hold, release와 오른쪽 터치 hold 전환을 검증한다.
- 현재 그래픽은 전부 개발용 Lua placeholder이며 최종 AetherAI 에셋이 아니다.
- 공식 AetherAI 로그인/export가 없으므로 최종 미술은 human-gated pending이다. 코드·상태머신·저장·충돌·슬롯·상점 개발은 계속한다.

- 상승 중 누르고 있는 `HOLD LEFT`·`HOLD RIGHT` 조종 버튼도 실제 조종 입력에 맞춰 시각적으로 강조해 현재 입력 방향을 즉시 표시한다.
- engine-hosted 표시 상태 테스트가 상승 조종 버튼의 기본 상태, 왼쪽/오른쪽 터치 hold 전환과 release를 검증한다.

- 행성 표본 획득 시 획득한 가치를 우주선 위치에서 위로 떠오르며 사라지는 `+$N` 플로팅 텍스트로 짧게(1초) 표시한다.
- engine-hosted 플로팅 텍스트 테스트가 표본 획득 시 생성된 `+$N` 텍스트, 시간 경과에 따른 상승·타이머 감소와 만료 뒤 제거를 검증한다.

- 귀환 슬롯 스핀은 릴 결과를 즉시 확정하지 않고 0.45초 동안 릴별로 0.15초씩 순차 정지하는 시각적 스핀 애니메이션을 재생한 뒤 확정 결과를 메시지로 표시한다. 스핀 중에는 슬롯 버튼이 `SLOT SPINNING...`으로 비활성화되어 추가 스핀 입력을 막는다.
- engine-hosted 슬롯 테스트가 스핀 중 슬롯 버튼 비활성화 상태와 애니메이션 종료 뒤 원래 완료 메시지·버튼 상태 복귀를 검증한다.

- 정산이 확정될 때 획득 표본 수와 슬롯 스핀 횟수를 `lastSampleCount`·`lastSlotSpinsCount`로 함께 저장하며, EARTH SHOP 상단 요약 카드가 `SETTLEMENT TOTAL $N`과 `SAMPLES (n) $N`·`SPINS (n) $N`을 한 번에 표시한다. 재출발·파괴 시 두 값도 0으로 초기화된다.
- engine-hosted 정산 테스트가 안전 귀환 정산 시 저장된 표본 수·슬롯 스핀 횟수와 재출발 뒤 초기화를 검증한다.

- 파괴(내구도 0) 시 잃은 표본 수·표본 가치와 슬롯 스핀 횟수·잠정 슬롯 보상을 `lastLostSampleCount`·`lastLostSampleValue`·`lastLostSlotSpinsCount`·`lastLostSlotValue`로 저장하며, SHIP DESTROYED 화면이 `LOST TOTAL $N`과 `SAMPLES (n) $N`·`SPINS (n) $N`을 안전 귀환 EARTH SHOP과 같은 형식으로 표시한다. 재출발 시 네 값 모두 0으로 초기화된다.
- engine-hosted 파괴 테스트가 상승·귀환 양쪽 경로의 파괴에서 잃은 표본 수·가치·슬롯 스핀 횟수·보상 저장과 재출발 뒤 초기화를 검증한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=destroyed` 개발 전용 진입 경로로 파괴 상태 재현)로 `SHIP DESTROYED`, `LOST TOTAL $155`, `SAMPLES (2) $80`, `SPINS (1) $75`, `META RESET BEST 0`, `NEXT SHIP STARTER`, `FUEL LV.0  HULL LV.0`, `TAP: START OVER`가 겹침·잘림 없이 `1080×1920` 세로 화면 안에 표시되는 것을 확인했다.

- EARTH SHOP 요약 카드와 SHIP DESTROYED 요약 카드가 해당 원정의 최고 도달 고도를 `PEAK ALT N`으로 함께 표시한다. 정산은 `expedition.lastAltitude`, 파괴는 `expedition.lastLostAltitude`에 최고 상승 고도(`maxAltitude`)를 저장하며 재출발 시 두 값 모두 0으로 초기화된다. 추가 줄에 맞춰 두 카드의 배경 박스 높이와 아래쪽 상점/재출발 터치 영역 좌표를 확장·이동했다.
- engine-hosted 정산 테스트가 정산·귀환 유지·재출발 각 시점의 `lastAltitude` 값을, 파괴 테스트가 `lastLostAltitude` 저장과 재출발 뒤 초기화를 검증한다.

- 출발 시점의 개인 최고 높이(`launchBestAltitude`)를 원정 시작마다 스냅샷하고, 정산·파괴 시 이번 원정 중 개인 최고 높이가 실제로 갱신됐는지 `lastNewBest`·`lastLostNewBest`로 저장한다. EARTH SHOP과 SHIP DESTROYED 요약 카드는 `PEAK ALT N` 바로 아래에 노란 `NEW BEST!` 배지를 조건부로 표시해 표본·슬롯·고도 요약과 함께 한 화면에서 갱신 여부를 확인할 수 있다. 파괴 카드는 추가 줄에 맞춰 배경 박스 높이와 아래 줄 좌표를 확장·이동했다.
- engine-hosted 정산 테스트가 최고 높이 갱신 시 `lastNewBest == true`, 갱신되지 않는 낮은 귀환 고도에서 `lastNewBest == false`를 검증하고, 파괴 테스트가 최고 높이 갱신 시 `lastLostNewBest == true`, 재출발 뒤 `false`로 초기화됨을 검증한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=destroyed` 개발 전용 진입 경로에 `maxAltitude`/`bestAltitude` 400 시딩 추가)로 `SHIP DESTROYED`, `LOST TOTAL $155`, `SAMPLES (2) $80`, `SPINS (1) $75`, `PEAK ALT 400`, 노란 `NEW BEST!`, `META RESET BEST 400`, `NEXT SHIP STARTER`, `FUEL LV.0 HULL LV.0`, `TAP: START OVER`가 겹침·잘림 없이 `1080×1920` 세로 화면 안에 표시되는 것을 확인했다 (`build/spaceship-runtime-preview-destroyed.png`).
- 안전 귀환 `NEW BEST!` 배지를 실제 캡처하려고 `main.lua`에 `GAME_CAPTURE_PHASE=settlement-newbest` 개발 전용 진입 경로를 추가해 확인하는 과정에서, EARTH SHOP 요약 카드가 실제 폰트 폭 기준으로 `SETTLEMENT TOTAL $N`이 136px 폭 박스에서 줄바꿈되고 `SPINS (n) $N`이 36px 폭 오른쪽 정렬 박스에 잘려 다음 줄과 겹치는 실제 렌더링 결함을 발견했다. 카드 문구를 `TOTAL $N`으로 줄이고 SAMPLES·SPINS·PEAK ALT·NEW BEST! 네 줄을 전체 폭 중앙 정렬로 세로 스택해 겹침을 제거했으며, 박스 높이를 54→62로 확장했다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1080×1920`)로 `EARTH SHOP` 요약 카드의 `TOTAL $155`, `SAMPLES (2) $80`, `SPINS (1) $75`, `PEAK ALT 400`, 노란 `NEW BEST!`가 겹침 없이 표시되는 것을 확인했다 (`build/spaceship-runtime-preview-settlement-newbest.png`). 단, 같은 캡처에서 EARTH SHOP 패널의 요약 카드 아래 연료/내구도/SCOUT 구매 행들과 `NO-HIT`/`SLOTS` 예측 줄들이 서로 겹쳐 읽을 수 없는 기존 레이아웃 결함이 별도로 확인됐다(이번 슬라이스 범위 밖, 다음 슬라이스로 이관).

- EARTH SHOP 요약 카드 아래 연료·내구도·SCOUT 구매 행과 `NO-HIT`/`SLOTS` 예측 텍스트가 서로 겹치던 레이아웃 결함을 고쳤다. 실제 LÖVE 폰트 프로브(`/tmp/fontcheck`)로 기본 폰트(높이 14px)에서 `T/F FUEL LV.0>1 $50 LEFT $105`(203px), `SCOUT MAX FUEL 140 HULL 3`(186px) 등 상점 문자열이 기존 88px 고정폭 컬럼을 크게 초과해 자동 줄바꿈되고 다음 줄과 겹치는 것을 측정으로 확인했다. `game/scenes/play.lua`의 `settlement` 분기 안에서만 씬에 캐시된 `love.graphics.newFont(8)`(높이 10px)로 전환하고, 행동/상태 2열 프린트는 102px/48px 컬럼으로, 나머지 미리보기·요약 문자열은 전체 폭 중앙 정렬로 재배치했으며 각 줄 간격을 11px로 재계산해(y=158부터 시작) `TAP: RELAUNCH`까지 12줄이 패널(y 70~320) 안에 줄바꿈·겹침 없이 들어가도록 했다. 상점 폰트는 draw 종료 시 이전 폰트로 복원한다.
- `PlayScene:touchpressed`의 정산 phase 터치 y 임계값(`FUEL`/`HULL`/`SCOUT`/`RELAUNCH`)을 새 행 좌표(150-179 / 179-212 / 212-256 / 256-320)에 맞춰 갱신했다. 기존 engine-hosted 터치 테스트(`y=174/208/244/300`)가 모두 새 임계값 범위 안에 들어가 별도 좌표 변경 없이 통과한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1440×2560`)로 `EARTH SHOP` 요약 카드 아래 `T/F FUEL LV.0>1 $50 LEFT $105`, `NO-HIT 720 SLOTS 8`, `T/H HULL LV.0>1 $75 LEFT $80`, `MAX FUEL 100 HULL 4`, `NO-HIT 600 SLOTS 6`, `SCOUT +40 FUEL / -1 HULL`, `SCOUT MAX FUEL 140 HULL 2`, `NO-HIT 840 SLOTS 9`, `T/V BUY SCOUT $125 LEFT $30`, `NEXT STARTER`, `MAX FUEL 100 HULL 3`, `FUEL LV.0 HULL LV.0`, `NO-HIT 600 SLOTS 6`, `TAP: RELAUNCH`가 서로 겹치거나 잘리지 않고 세로 화면 안에 표시되는 것을 확인했다 (`build/spaceship-runtime-preview-settlement-newbest-current.png`, `build/spaceship-runtime-preview-settlement-newbest.png`).

- SHIP DESTROYED 화면도 EARTH SHOP과 같은 좁은 고정폭 컬럼(`viewport.width - 32` 전체폭 12줄, 기존 12px 줄간격) 문제를 실제 폰트 폭으로 확인해 EARTH SHOP과 동일한 씬 캐시 `love.graphics.newFont(8)`(높이 10px) 작은 폰트와 전체폭 중앙 정렬 패턴을 적용했다. `y=178`부터 11px 간격으로 `SHIP DESTROYED`, `LOST TOTAL $N`, `SAMPLES (n) $N`, `SPINS (n) $N`, `PEAK ALT N`, 조건부 `NEW BEST!`, `META RESET BEST N`, `NEXT <SHIP>`, `FUEL LV.n HULL LV.n`, `TAP: START OVER`가 패널(y 174~308) 안에 순서대로 배치되도록 재계산했으며 draw 종료 시 이전 폰트로 복원한다.
- 상승·귀환 중 표시되는 `RISK -N`/`SAMPLE $N` 접근 경고 라벨의 기존 66px 고정폭 `printf(..., "center")`를 실제 폰트 폭 기준 좌표로 교체했다. 새 `PlayScene.clampLabelX(centerX, textWidth, viewportWidth, margin)` 헬퍼가 현재 폰트의 실제 텍스트 폭으로 라벨을 행성 중심에 맞춰 좌측 정렬 `print`로 그리되 화면 좌우 2px 여백 안으로 clamp해, 화면 가장자리 근처 행성의 넓은 라벨이 잘리지 않도록 했다.
- engine-hosted 테스트가 `PlayScene.clampLabelX`의 중앙 정렬 좌표, 우측 경계 clamp(`178`쪽), 좌측 경계 clamp(`2`쪽)와 좁은 텍스트의 정상 중앙 좌표 4가지 경우를 검증한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=ascending-wide-warning` 개발 전용 진입 경로로 화면 오른쪽 가장자리 근처 행성 배치)로 `SAMPLE $999`, `LETHAL -3` 라벨이 `1440×2560` 세로 화면 오른쪽 가장자리 안쪽에 잘리지 않고 표시되는 것을 확인했다 (`build/spaceship-runtime-preview-ascending-wide-warning.png`).

- 표본 종류별 시각 구분을 위해 `game/world.lua`에 `world.sampleTier(planet)`을 추가했다. 행성 고도(`-planet.y`) 기준 `0~299`는 `common`, `300~799`는 `rare`, `800` 이상은 `epic` 3단계로 분류하며 `world.sampleValue`와 같은 고도 축을 공유해 가치·희귀도가 같은 방향으로 증가한다.
- `game/scenes/play.lua`에 `PlayScene.sampleTierColor(tier)`를 추가해 `common`은 회백색, `rare`는 청록색, `epic`은 금색 링 색을 반환한다. 상승 중 아직 표본을 획득하지 않은(`self.discovered[planet.id]`가 false인) 행성에는 채우기 색 위에 등급 색 외곽 링을 추가로 그려 기존 흰 테두리 링과 별개로 접근 전에도 행성 등급을 시각적으로 구분할 수 있게 했다. 표본을 이미 획득한 행성에는 등급 링을 그리지 않는다.
- engine-hosted 테스트가 `world.sampleTier`의 세 구간 경계값(299/300, 799/800)과 `PlayScene.sampleTierColor`의 세 등급이 서로 다른 색을 반환하는지 검증한다.
- `main.lua`에 `GAME_CAPTURE_PHASE=ascending-sample-tiers` 개발 전용 진입 경로를 추가해 세 등급(`common`/`rare`/`epic`)의 모의 행성을 동시에 배치했다. 실제 LÖVE runtime capture(`1080×1920`)로 `common` 흰색 링, `rare` 청록색 링, `epic` 금색 링이 서로 다른 색으로 렌더링되는 것을 확인했다 (`build/spaceship-runtime-preview-ascending-sample-tiers.png`).

- 귀환 슬롯의 세 심볼(`COMET`/`PLANET`/`STAR`)이 기존에 균등 확률로 뽑히던 것을 명확한 확률/기대값 밸런싱으로 교체했다. `game/expedition.lua`에 `slotWeights`(`COMET 5`, `PLANET 4`, `STAR 1`, 총 가중치 10)를 추가해 `COMET 50%`·`PLANET 40%`·`STAR 10%`의 확률로 뽑히게 했고, `M.slotSymbolProbability(symbol)`·`M.weightedSlotSymbol(roll)`·`M.slotExpectedValue()`를 노출해 심볼별 확률과 스핀당 기대 보상(가중치 브루트포스로 계산한 정확값)을 다른 코드나 향후 UI가 조회할 수 있게 했다. 스핀 로직(`spinSlot`)은 `run.slotRandom(#slotSymbols)`(균등 1~3) 대신 `run.slotRandom(slotTotalWeight)`(1~10)로 굴려 가중치 심볼을 뽑는다.
- engine-hosted 테스트가 `slotTotalWeight == 10`, 세 심볼의 정확한 확률(`0.5`/`0.4`/`0.1`), `weightedSlotSymbol`의 경계값 매핑(`1~5→COMET`, `6~9→PLANET`, `10→STAR`)과 `slotExpectedValue()`의 확률 합 `1`·스핀당 기대 보상 `18.585`를 검증한다. 기존 귀환/파괴/터치 시나리오 테스트의 주입 `slotRandom` 값도 새 1~10 스케일과 심볼 매핑에 맞춰 갱신해(`STAR`=10, `PLANET`=6, `COMET`=1) 계속 같은 시나리오(스타 트리플, COMET-COMET-PLANET 등)를 재현하도록 했다.

- 귀환 슬롯 확률/기대값을 엔진 로직에만 머물지 않고 실제 화면에 노출했다. `game/scenes/play.lua`에 `PlayScene:slotOddsLine()`을 추가해 `expedition.slotSymbolProbability`와 `expedition.slotExpectedValue()`를 조회한 `"ODDS C50% P40% S10%  AVG $18.58"` 문자열을 반환하며, `returning` phase draw에서 씬 캐시 `love.graphics.newFont(8)` 작은 폰트로 조종/슬롯 버튼 행 바로 위(y=197, 전체 폭 중앙 정렬)에 표시한다.
- engine-hosted 테스트가 `PlayScene:slotOddsLine()`의 정확한 확률·기대값 문자열(`"ODDS C50% P40% S10%  AVG $18.58"`, LÖVE 부동소수점 합산 기준 반올림)을 검증한다.
- `main.lua`에 `GAME_CAPTURE_PHASE=returning-odds` 개발 전용 진입 경로를 추가했다. 실제 LÖVE runtime capture(`1080×1920`)로 귀환 HUD(`EARTH IN 500`, `RETURN 0%  12s LEFT`)와 `ODDS C50% P40% S10%  AVG $18.58`가 `LEFT`/`SPIN 3`/`RIGHT` 버튼과 겹치지 않고 화면 안에 두 줄로 줄바꿈되어 표시되는 것을 vision 확인했다(`build/spaceship-runtime-preview-returning-odds.png`, 로컬 산출물로 커밋 제외).
- 슬롯 확률/기대값을 `LAUNCH LOADOUT`(줄임말 `"C50 P40 S10  AVG $18.58"`, 씬 캐시 작은 폰트)과 EARTH SHOP `NEXT <SHIP>` 미리보기 블록 마지막 줄에도 노출했다. `PlayScene:loadoutLines()`와 `PlayScene:shopLoadoutLines()`가 각각 `odds` 필드로 `slotOddsLine()` 결과를 반환하며 draw에서 기존 항목들 아래(launch: y=274 작은 폰트, settlement: forecast 다음 행)에 그린다.
- engine-hosted 테스트가 `loadoutLines().odds`·`shopLoadoutLines().odds` 둘 다 `"C50 P40 S10  AVG $18.58"`을 반환하는지 검증한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1080×1920`)로 EARTH SHOP 패널에 새 `odds` 줄을 추가한 뒤 vision으로 확인한 결과, 기존에 이미 존재하던 레이아웃 결함(14줄 텍스트가 `rowStep=11`·`row=158` 시작으로 패널 하단(y=320)과 `DEV PLACEHOLDER` 푸터(y=307)를 넘어 `TAP: RELAUNCH`가 푸터 텍스트와 겹침)을 재확인했다. `game/scenes/play.lua`의 settlement 분기에서 `row=158→154`, `rowStep=11→10`으로 좁혀 마지막 줄(`TAP: RELAUNCH`, 14번째 행)이 y≈284에서 그려지도록 해 푸터(y=307)와 겹치지 않게 했다. 기존 `touchpressed` y 임계값(150-179/179-212/212-256/256-320)은 새 행 좌표(fuel≈154, hull≈184, ship≈234, relaunch≈284) 범위 안에 그대로 들어가 별도 조정 없이 통과한다.
- engine-hosted 정산/상점/터치 테스트(`make test`)가 좁힌 행 간격에서도 모두 GREEN이다. 이 결함은 오늘 이전 커밋(`b8aff33`)에서부터 존재했으며 이번 슬라이스에서 처음 근본 수정됐다.

- 좁힌 EARTH SHOP 행 간격(`row=154`, `rowStep=10`)을 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1440×2560`)로 재캡처해 vision으로 확인한 결과 `TAP: RELAUNCH`와 `DEV PLACEHOLDER` 사이에 겹침이 없음을 최종 확인했다. 같은 캡처에서 최상단 HUD 상태 줄 `F100 H3/3 SETTLEMENT S00`(실제 폰트 폭 175px, 뷰포트 180px에서 clamp/여백 없이 화면 우측 끝까지 붙어 잘릴 위험이 있는 폭)이 발견되어, `PlayScene:hudLines()`의 `status` 포맷을 `%-9s`(phase 전체 이름)에서 `%-6s`(phase 이름을 6자로 잘라 SETTLE/ASCEND/RETURN/LAUNCH/DESTRO로 표시, 실제 최대 폭 146~168px)로 좁혔다.
- engine-hosted 테스트가 `settlement` phase의 `hudLines().status == \"F100 H3/3 SETTLE S00\"`를 검증한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1440×2560`)로 수정 후 상태 줄이 `F100 H3/3 SETTLE S00`으로 화면 안에 완전히 표시되고, EARTH SHOP 12줄 레이아웃 전체가 겹침·잘림 없이 표시되는 것을 vision으로 재확인했다 (`build/spaceship-runtime-preview-settlement-newbest-statusfix.png`, 로컬 산출물로 커밋 제외).

- `다음 한 가지`의 축약 상태 줄 재확인 작업 중 `ascending` phase를 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=ascending-wide-warning`, `1440×2560`)로 재검사해 `F099 H3/3 ASCEND S00` 상태 줄 자체는 잘리지 않았지만, 별도의 실제 레이아웃 결함을 vision으로 발견했다: 하단 조종 버튼의 기본 폰트(높이 14px) `HOLD RIGHT` 문구(실측 폭 75px)가 76px 버튼 박스 폭에 비해 좁은 여유로 자동 줄바꿈되어 두 번째 줄(`RIGHT`)이 버튼 배경 상자(y 254~278) 아래로 흘러나와 `TAP TO LAUNCH` 문구와 겹치는 것을 확인했다(`build/spaceship-runtime-preview-ascending-wide-warning-recheck.png`).
- `game/scenes/play.lua`의 `ascending` phase 조종 버튼 라벨을 EARTH SHOP/SHIP DESTROYED/귀환 ODDS 줄과 같은 씬 캐시 `love.graphics.newFont(8)`(작은 폰트, 실측 `HOLD RIGHT` 폭 50px)로 전환해 76px 버튼 폭 안에 한 줄로 들어가도록 고쳤다. draw 종료 전에 이전 폰트로 복원한다. 이 결함은 `ascending` HUD 상태 줄 자체와 무관하게 조종 버튼 라벨에서 발생했으며, `launch → ascending` 어느 시점에도 이미 존재했던 기존 결함이었다(이번 슬라이스에서 처음 발견·수정).
- 상승 중 `love.graphics` 헤드리스 비활성화로 실제 렌더 폭을 engine-hosted 테스트로 직접 검증할 수 없어(`conf.lua`가 `GAME_HEADLESS=1`일 때 `graphics` 모듈을 끔, `self_test.lua`가 `:draw()`를 호출하지 않음), 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=ascending-wide-warning`, `1440×2560`)로 수정 후 `HOLD RIGHT`가 버튼 상자 안에 한 줄로 표시되고 `TAP TO LAUNCH`와 겹치지 않는 것을 vision으로 재확인했다 (`build/spaceship-runtime-preview-ascending-wide-warning-holdfix.png`, 로컬 산출물로 커밋 제외). `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과.

- `returning` phase 하단 `LEFT`/`RIGHT`/`SPIN N` 버튼 라벨의 좁은-폭 줄바꿈 위험을 실제 폰트 프로브(`/tmp/fontcheck`)로 측정해 확인했다: 기본 폰트(높이 14px)에서 `LEFT`(30px)·`RIGHT`(40px)·`SPIN 3`(40px)는 각각 50px/50px/60px 버튼 폭 안에 들어가 이 시나리오에서는 실제로 줄바꿈이 발생하지 않았지만(가장 넓은 `NO SLOTS`도 64px로 60px 슬롯 버튼 폭을 8px 초과할 수 있어 여유가 매우 좁음), 일관성을 위해 `ascending`/`EARTH SHOP`/`SHIP DESTROYED`와 같은 씬 캐시 `love.graphics.newFont(8)`(작은 폰트, 실측 `LEFT` 20px·`RIGHT` 26px·`SPIN 3` 27px·`NO SLOTS` 43px)로 통일해 여유 폭을 넓혔다. draw 종료 시 이전 폰트로 복원한다.
- engine-hosted 테스트(`make test`)가 회귀 없이 GREEN이다(그래픽 헤드리스 비활성화로 텍스트 폭 자체는 직접 단위 테스트할 수 없는 기존 제약은 `ascending` HOLD RIGHT 수정 때와 동일).
- 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=returning-odds`, `1440×2560`)로 `LEFT`/`SPIN 3`/`RIGHT` 세 버튼이 각 박스 안에서 한 줄로 렌더링되고 서로 또는 위쪽 `ODDS` 줄과 겹치지 않는 것을 vision으로 확인했다 (`build/spaceship-runtime-preview-returning-odds-buttonfix.png`, 로컬 산출물로 커밋 제외). `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과.

## 다음 한 가지

- 상점(EARTH SHOP)과 SHIP DESTROYED 두 화면 모두 세로 화면에서 실제 손가락 터치 타겟 크기(각 행 34px 미만)가 접근성 기준(iOS/Android 최소 44px 권장)에 못 미치는지 실기기 기준으로 검토가 필요하다.
- `returning`·`destroyed`·`launch` phase의 HUD 상태 줄도 새 6자 축약(`RETURN`/`DESTRO`/`LAUNCH`)이 실제 폭 기준으로 잘리지 않는지 실기기 캡처로 각각 재확인이 필요하다(이번 슬라이스는 `settlement`·`ascending` 두 phase만 실제 캡처로 검증했다. `ascending`은 상태 줄 자체는 문제없었으나 하단 조종 버튼 라벨 겹침 결함을 별도로 발견·수정했다).

## 완료 조건

- `make verify LOVE=/Users/jm/.local/bin/love` 통과 (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:24`)
- 세로 실제 런타임 캡처 `540×960`에서 실제 최대 연료·내구도와 `NO-HIT 600  SLOTS 6`을 포함한 launch loadout, `TAP TO LAUNCH`, `DEV PLACEHOLDER` 표시 확인
- 개인 최고 높이 영구 저장 engine-hosted 자동 테스트 통과
- 출발·정산 HUD의 개인 최고 높이 복구 표시 engine-hosted 자동 테스트 통과
