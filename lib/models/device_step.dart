enum DeviceStep {
  workstationSetup, // STEP 00: 조립대 번호 초기 설정
  orderCall, // STEP 01: 대기번호 호출
  waiting, // STEP 02: 부품 도착 대기
  authenticated, // (테스트 전용) 인증 완료 — 실제 흐름에서는 건너뜀, DemoMenu로만 진입
  assembling, // STEP 03: 조립 중
  completed, // STEP 04: 조립 완료
  invalidQr, // ERROR 1: 잘못된 QR
  wrongWorkstation, // ERROR 2: 조립대 불일치
  noShow, // ERROR 3: 호출 시간 초과(노쇼)
}
