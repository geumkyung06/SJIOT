# SJIOT 플랫폼/조립대 백엔드

## 1. 프로젝트 소개
- 키캡 커스터마이징 IOT 서비스
- CO-SHOW 2026 전시 목표

## 2. 시스템 아키텍처
- 전체 그림: Flutter 키오스크 → Flask(Cloud Run) → Redis(런타임 상태) / Mobius(영속 저장)
- 왜 이런 구조인가: Redis가 단일 진실 소스, Mobius는 로깅/영속용 (COSS append-only라 직접 조회 불가)
- ESP32가 폴링 방식인 이유 (NAT 뒤라 구독 push 못 받음)

## 3. API 문서
- Swagger UI 링크 ([/apidocs/](https://sjiot-backend-294910862364.asia-northeast1.run.app/apidocs/#/))
- 핵심 흐름 요약: 주문 생성 → 배정 대기 → QR 스캔 → 조립 시작 → 완료
- 

## 4. 개발 환경 설정
- git clone, venv, pip install -r requirements.txt --break-system-packages
- env.yaml 예시 (실제 값 없이 키 목록만)
- 로컬 실행 (python app.py)

## 5. 배포
- gcloud run deploy 명령어 그대로

## 6. Redis 키 구조

## 7. 알려진 이슈 / TODO


## 8. 팀 / 담당
- 백엔드: lgk (전체 저장소 관리)
- 프론트: gsj, awj
- 브랜치 전략: main / lgk / gsj / awj / front_device / front_kiosk