import 'package:flutter/material.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // Supabase 데이터 가져오는 함수
  Future<List<Itinerary>> _fetchItineraries() async {
    final supabase = Supabase.instance.client;

    // 'Itinerary' 테이블에서 모든 데이터를 가져옴 (최신순 정렬)
    final response = await supabase
        .from('Itinerary')
        .select('*, Users(name, profile_image_url)')
        .order('created_at', ascending: false);

    // 받아온 데이터를 List<Itinerary>로 변환
    final data = response as List<dynamic>;
    return data.map((json) => Itinerary.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase 연동 테스트')),
      body: FutureBuilder<List<Itinerary>>(
        future: _fetchItineraries(), // 위의 함수 실행
        builder: (context, snapshot) {
          // 1. 로딩 중일 때
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. 에러가 났을 때
          if (snapshot.hasError) {
            return Center(child: Text('에러 발생: ${snapshot.error}'));
          }

          // 3. 데이터가 없을 때
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('데이터가 없습니다.'));
          }

          // 4. 데이터가 있을 때 (리스트로 보여주기)
          final itineraries = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16), // 전체 여백 추가
            itemCount: itineraries.length,
            itemBuilder: (context, index) {
              final item = itineraries[index];

              // 날짜 포맷팅 (예: 2024-12-01)
              final dateStr = item.startDate != null
                  ? "${item.startDate!.year}-${item.startDate!.month}-${item.startDate!.day}"
                  : "날짜 미정";

              // ListView.builder 내부의 return 부분을 이것으로 교체하세요
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 썸네일 이미지 (왼쪽)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.coverImageUrl != null
                          ? Image.network(
                        item.coverImageUrl!,
                        width: 100, // 사진 크기를 조금 키웠습니다
                        height: 100,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 2. 오른쪽 정보 영역
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // (1) 제목
                          Text(
                            item.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // (2) 설명
                          Text(
                            item.description ?? '',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // (3) 날짜 및 테마 배지
                          Row(
                            children: [
                              // 날짜 배지 (분홍색 배경)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F5), // 연한 분홍색
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 12, color: Colors.pinkAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateRange(item.startDate, item.endDate), // 위에서 만든 함수 사용
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.pinkAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 테마 배지 (회색 배경)
                              if (item.theme != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.theme!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // (4) 작성자 정보 (프로필 + 이름 + 지역)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 8,
                                // 프로필 이미지가 있으면 보여주고, 없으면 기본 아이콘
                                backgroundImage: item.author?.profileImage != null
                                    ? NetworkImage(item.author!.profileImage!)
                                    : null,
                                child: item.author?.profileImage == null
                                    ? const Icon(Icons.person, size: 10) // 이미지 없을 때 아이콘
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.author?.name ?? "알 수 없음", // 이름 표시
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(width: 4),
                              const Text("•", style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 4),
                              const Text(
                                "Seoul", // 임시 지역 (추후 DB 연동 필요)
                                style: TextStyle(fontSize: 12, color: Colors.pinkAccent, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // (5) 하단 통계 (장소 수, 좋아요, 조회수, 공유)
                          Row(
                            children: [
                              _buildStatItem(Icons.map_outlined, "4 stops"), // 장소 수
                              const SizedBox(width: 12),
                              _buildStatItem(Icons.favorite_border, "${item.viewCount}"), // 좋아요 (임시로 viewCount 사용)
                              const SizedBox(width: 12),
                              _buildStatItem(Icons.remove_red_eye_outlined, "${item.viewCount}"), // 조회수
                              const SizedBox(width: 12),
                              _buildStatItem(Icons.copy_outlined, "342"), // 공유 수
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 날짜를 "월/일" 또는 "월/일 ~ 월/일" 형태로 바꿔주는 함수
String _formatDateRange(DateTime? start, DateTime? end) {
  if (start == null) return "날짜 미정";

  // "월/일" 형태 (예: 12/1)
  String startStr = "${start.month}/${start.day}";

  // 종료일이 없거나 시작일과 같다면 시작일만 표시
  if (end == null || (start.year == end.year && start.month == end.month && start.day == end.day)) {
    return startStr;
  }

  // 종료일이 다르면 범위 표시 (예: 12/1 ~ 12/3)
  String endStr = "${end.month}/${end.day}";
  return "$startStr ~ $endStr";
}

// 통계 아이콘 + 텍스트 위젯 생성 함수
Widget _buildStatItem(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    ],
  );
}