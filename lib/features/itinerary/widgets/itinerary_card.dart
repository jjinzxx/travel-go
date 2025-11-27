import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';

class ItineraryCard extends StatelessWidget {
  final Itinerary itinerary; // 데이터 받기
  final VoidCallback? onTap; // 클릭했을 때 실행할 함수 (선택 사항)
  final VoidCallback? onDeleteSuccess; // 삭제 성공 시 실행할 콜백

  const ItineraryCard({
    super.key,
    required this.itinerary,
    this.onTap,
    this.onDeleteSuccess,
  });

  // 삭제 확인 알림창 띄우기
  Future<void> _confirmDelete(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Schedule"),
          content: const Text("Are you sure you want to delete this itinerary?\nDeleted data cannot be recovered."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 취소
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // 삭제 확인
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // 사용자가 '삭제'를 눌렀다면 실제로 삭제 진행
    if (result == true) {
      await _deleteItinerary(context);
    }
  }

  // 실제 Supabase 삭제 로직
  Future<void> _deleteItinerary(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;

      // DB에서 해당 ID의 일정 삭제
      await supabase
          .from('Itinerary')
          .delete()
          .eq('itinerary_id', itinerary.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("The schedule has been deleted.")),
        );
        // 부모 페이지(리스트)에 "나 삭제됐어! 새로고침해!" 라고 알림
        onDeleteSuccess?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 로그인한 유저 ID 확인
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // 내가 작성한 글인지 확인 (삭제 버튼 표시용)
    final isMyPost = currentUserId != null && currentUserId == itinerary.userId;

    // 날짜 포맷팅
    final dateStr = _formatDateRange(itinerary.startDate, itinerary.endDate);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // 1. 카드 본문 디자인
          Container(
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
                // (1) 썸네일 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: itinerary.coverImageUrl != null
                      ? Image.network(
                    itinerary.coverImageUrl!,
                    width: 100,
                    height: 100,
                    // 성능 최적화: 작은 사이즈로 캐싱
                    cacheWidth: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  )
                      : Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),

                // (2) 텍스트 정보 영역
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Padding(
                        padding: const EdgeInsets.only(right: 24.0), // 삭제 버튼 공간 확보
                        child: Text(
                          itinerary.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 설명
                      Text(
                        itinerary.description ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // 날짜 및 테마 배지
                      Row(
                        children: [
                          // 날짜 배지
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 12, color: Colors.pinkAccent),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
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

                          // 테마 배지
                          if (itinerary.theme != null)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  itinerary.theme!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 작성자 + 참여 멤버 리스트
                      Row(
                        children: [
                          // 1. 작성자
                          _buildAvatar(itinerary.author),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              itinerary.author?.name ?? "Unknown",
                              style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 2. 멤버 리스트 (있을 때만 표시)
                          if (itinerary.members.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(width: 1, height: 12, color: Colors.grey[300]), // 구분선
                            const SizedBox(width: 8),

                            // 최대 3명까지만 아이콘으로 표시
                            ...itinerary.members.take(3).map((member) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _buildAvatar(member),
                            )),

                            // 3명 넘으면 숫자(+N) 표시
                            if (itinerary.members.length > 3)
                              Text(
                                "+${itinerary.members.length - 3}",
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              )
                          ]
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 하단 통계 아이콘들 (실제 데이터 반영)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // 장소 수
                            _buildStatItem(
                                Icons.map_outlined,
                                "${itinerary.placeCount} stops"
                            ),
                            const SizedBox(width: 12),

                            // 좋아요 수
                            _buildStatItem(
                                Icons.favorite_border,
                                "${itinerary.likeCount}"
                            ),
                            const SizedBox(width: 12),

                            // 조회수
                            _buildStatItem(
                                Icons.remove_red_eye_outlined,
                                "${itinerary.viewCount}"
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 삭제 버튼 (내가 쓴 글일 때만 우측 상단 표시)
          if (isMyPost)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _confirmDelete(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                        Icons.delete_outline,
                        color: Colors.grey[400],
                        size: 20
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 내부 헬퍼 함수: 통계 아이콘
  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // 내부 헬퍼 함수: 프로필 이미지
  Widget _buildAvatar(Author? author) {
    return CircleAvatar(
      radius: 9,
      backgroundColor: Colors.grey[200],
      backgroundImage: author?.profileImage != null
          ? NetworkImage(author!.profileImage!)
          : null,
      child: author?.profileImage == null
          ? const Icon(Icons.person, size: 12, color: Colors.grey)
          : null,
    );
  }

  // 내부 헬퍼 함수: 날짜 포맷
  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return "Date TBD";
    String startStr = "${start.month}/${start.day}";
    if (end == null || (start.year == end.year && start.month == end.month && start.day == end.day)) {
      return startStr;
    }
    String endStr = "${end.month}/${end.day}";
    return "$startStr ~ $endStr";
  }
}