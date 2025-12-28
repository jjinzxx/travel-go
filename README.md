<div align="center">

![header](https://capsule-render.vercel.app/api?type=Waving&color=0:A50034,100:C73659&height=280&section=header&text=Travel%20Go&fontSize=80&fontColor=ffffff&fontAlignY=40&desc=AR%20%2B%20AI%20Based%20Travel%20Experience%20for%20Foreigners&descAlignY=60&animation=fadeIn)


  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white">
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white">
  <br>
  <img src="https://img.shields.io/badge/Google_Maps-4285F4?style=for-the-badge&logo=google-maps&logoColor=white">
  <img src="https://img.shields.io/badge/AR_Location_Viewer-00C853?style=for-the-badge&logo=android&logoColor=white">
  <img src="https://img.shields.io/badge/Vue.js-4FC08D?style=for-the-badge&logo=vue.js&logoColor=white">
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white">

  <br><br>
</div>


<br>

## Travel Go
**해외 여행자를 위한 AR 기반 거리뷰 & AI 일정 추천 여행 서비스**

국내 여행을 온 해외 여행자들이 언어와 정보 장벽 없이  
주변 장소를 직관적으로 탐색하고, 취향 기반으로 일정을 추천받을 수 있는 서비스입니다.  
LG Travel+에서 집 안에서 시작한 여행 경험을, Travel Go를 통해 집 밖에서도 이어가도록 설계했습니다.

<br>

## 0. Team & Roles

- 팀 구성: 6명  
  (백엔드 2, 프론트엔드 1, DB 2, 문서 1)

- 내 역할: **백엔드 개발(Main), 데이터베이스 설계(Main), 데이터 분석**

- 담당 업무:
  - Supabase 기반 데이터베이스 설계 및 ERD 구축
  - 요구사항 분석 및 크롤링 데이터 분석
  - Itinerary, My Luggage(LikedPlaces) 설계 및 DB 연동
  - 일정 CRUD, 조회수/좋아요 집계 로직 구현
  - AI 추천을 위한 데이터 파이프라인 설계

<br>

## 1. Overview

### 핵심 기능 요약
- AR 거리뷰를 통한 주변 장소 정보 시각화
- 여행 일정(Itinerary) CRUD 및 공유/복제
- 좋아요 기반 My Luggage 수집
- OpenAI API 기반 장소 추천
- Travel+와 연계된 사용자 취향 데이터 활용

<br>

## 2. Motivation

- 해외 여행자의 실제 문제점
  - 지도 앱 사용 시 정보 과다 및 언어 장벽
  - 일정 계획의 피로도
  - 개인 취향을 반영하지 못하는 추천

- 해결 방향
  - AR 기반 시각적 탐색으로 정보 접근성 개선
  - 좋아요 데이터(Luggage)를 중심으로 한 취향 수집
  - DB 중심 설계로 추천과 통계를 안정적으로 처리

<br>

## 3. Demo

- 시연 영상:
- 스크린샷:
  - AR 거리뷰 화면
  - Itinerary 생성/조회 화면
  - My Luggage 화면

- 대표 플로우:
  - Itinerary 생성 → 장소 좋아요 → My Luggage 반영 → AI 추천

<br>

## 4. Tech Stack

### App / Backend
- Flutter (Dart)
- supabase_flutter (Auth, DB, Storage)
- OpenAI API (AI 장소 추천)
- geolocator, maps_flutter, ar_location_view

### Web
- Vue.js
- TypeScript, JavaScript(ES6+)
- HTML5, CSS3

### Database / BaaS
- Supabase
  - PostgreSQL
  - Auth (Email / Social Login)
  - Storage (이미지 호스팅)
  - RPC (PL/pgSQL Stored Functions)

- ERD Tool: dbdiagram.io

### Infra / DevOps
- Web 배포: Vercel
- App 배포: Android APK (QR Code)
- CI/CD: GitHub Actions

### Collaboration
- GitHub Flow
- Notion (기획, API 명세)
- Figma (UI/UX)

<br>

## 5. Architecture & DB

### System Architecture
- Flutter(App) + Vue(Web)
- Supabase (Postgres / Auth / Storage / RPC)
- OpenAI API

### 주요 테이블
- Users
- Place / Region
- Itinerary / ItineraryDay / ItineraryPlace
- LikedPlaces (My Luggage)
- ItineraryLikes, ItineraryMember
- 로그 테이블 (view_log, search_log, session_log 등)

### 핵심 관계
- Region(1) – Place(N)
- Users(1) – Itinerary(N)
- Itinerary(1) – ItineraryDay(N)
- ItineraryDay(1) – ItineraryPlace(N)
- Users(1) – LikedPlaces(N) – Place(1)

### RPC (Stored Functions)
- `copy_itinerary(...)`  
  일정과 하위 장소를 트랜잭션으로 묶어 Deep Copy
- `increment_view_count(...)`  
  동시성 문제를 고려한 조회수 원자적 증가
- `search_places(...)`  
  다중 필드 통합 검색

<br>

## 6. Implementation / Features

### 구현 완료
- Itinerary CRUD 및 일정 공유/복제
- LikedPlaces 기반 My Luggage 수집
- AR 거리뷰 기반 장소 정보 표시
- 조회수/좋아요 집계(RPC)
- OpenAI API 기반 장소 추천
- 실시간 협업 일정 편집

### 미구현 / 부분 구현
- 다국어 UI 완전 지원 (부분)
- 사용자 행동 기반 추천 고도화 (부분)

### 내가 구현한 핵심
- Itinerary 전반 설계 및 구현
- Supabase RPC를 활용한 일정 Deep Copy 트랜잭션

### 트러블슈팅
- 문제: 
- 원인: 
- 해결: 

<br>

## 7. Timeline

- 개발 기간: 2025.11.03 ~ 2025.12.12

- 주요 마일스톤:
  - 기획 및 요구사항 정의
  - 프로젝트 주제 선정 및 WBS 수립
  - 기획 발표 및 UI/UX 설계
  - ERD 설계 및 Supabase 구축
  - 시스템 아키텍처 확정
  - 최종 산출물 제출 및 발표

<br>

## 8. Retrospective

### 느낀점
-

### 개선 계획
- 로그 테이블 기반 추천 알고리즘 정교화
- 다국어 UI 완성 및 글로벌 사용자 대응

<br><br><br>


<div align="center">

<p>
  LG전자 DX School 3기 · DX Project<br>
  Team Jacks
</p>

<p>
  <a href="https://github.com/jjinzxx">GitHub</a> ·
  <a href="https://blog.naver.com/epspqm823">Blog</a> ·
  <a href="#">Request Feature</a>
</p>

<p>
  <img src="https://img.shields.io/github/last-commit/jjinzxx/travel-go?color=red&label=Last%20Update&logo=github&style=flat-square">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square">
</p>

<p>
  © 2025 Travel Go
</p>

</div>
<div align="center">

![footer](https://capsule-render.vercel.app/api?type=Waving&color=0:C73659,100:A50034&height=120&section=footer)

</div>
