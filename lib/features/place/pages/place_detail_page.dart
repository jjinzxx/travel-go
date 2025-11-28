import 'package:flutter/material.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/core/services/place_service.dart';

class PlaceDetailPage extends StatefulWidget {
  final Place place;

  const PlaceDetailPage({super.key, required this.place});

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final _placeService = PlaceService();
  late Place _place;

  // 상태 변수 분리
  bool _isSaved = false; // SavedPlace 여부
  bool _isLiked = false; // LikedPlace 여부
  bool _isDescriptionExpanded = false; // 설명 확장 여부

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _checkUserStatus(); // 초기 상태 확인
  }

  // 초기 상태 로딩
  Future<void> _checkUserStatus() async {
    try {
      final status = await _placeService.fetchPlaceStatus(_place.id);
      if (mounted) {
        setState(() {
          _isSaved = status['isSaved']!;
          _isLiked = status['isLiked']!;
        });
      }
    } catch (_) {}
  }

  // 저장 버튼 클릭
  Future<void> _handleSave() async {
    // regionId가 없으면(null) 저장을 못하므로 방어 코드
    if (_place.regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Region info missing.")));
      return;
    }

    try {
      // regionId 전달
      final newState = await _placeService.toggleSave(_place.id, _place.regionId!);
      setState(() => _isSaved = newState);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newState ? "Saved to Luggage!" : "Removed from Luggage")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login required or Error")));
    }
  }

  // 좋아요 버튼 클릭
  Future<void> _handleLike() async {
    if (_place.regionId == null) return;

    try {
      // regionId 전달
      final newState = await _placeService.toggleLike(_place.id, _place.regionId!);
      setState(() => _isLiked = newState);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login required")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. 헤더
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _place.imageUrl != null
                      ? Image.network(_place.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_place.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        Text(
                          _place.address ?? "No address available",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        // Text(
                        //   _place.category ?? "Uncategorized",
                        //   style: const TextStyle(color: Colors.white70, fontSize: 12),
                        // ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // 2. 본문 내용 (버튼 연결 부분 수정됨!)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 액션 버튼들
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 1. Map (기능 추후 구현)
                      _buildActionButton(icon: Icons.location_on_outlined, label: "Map", onTap: () {}),

                      // 2. Save (북마크 / SavedPlace)
                      _buildActionButton(
                          icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          label: "Save",
                          onTap: _handleSave,
                          isActive: _isSaved // 저장되면 파란색
                      ),

                      // 3. Like (하트 / LikedPlace)
                      _buildActionButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: "Like",
                        onTap: _handleLike,
                        isActive: _isLiked, // 좋아요하면 파란색 (또는 빨간색 커스텀 가능)
                        activeColor: Colors.red, // 하트는 빨간색이 국룰!
                      ),

                      // 4. AR View
                      _buildActionButton(icon: Icons.camera_alt_outlined, label: "AR View", isPrimary: true, onTap: () {
                        Navigator.pushNamed(context, '/ar');
                      }),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text("About", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _place.description ?? "No description available.",
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              fontWeight: FontWeight.w300,
                          ),
                          // [핵심] 펼쳐졌으면 제한 없음(null), 닫혔으면 3줄 제한
                          maxLines: _isDescriptionExpanded ? null : 3,
                          // 넘치면 ... 처리
                          overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),

                        // 내용이 길 때만 'Read More' 버튼 표시 (예: 80자 이상일 때)
                        if ((_place.description?.length ?? 0) > 80) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isDescriptionExpanded = !_isDescriptionExpanded;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end, // 오른쪽 정렬
                              children: [
                                Text(
                                  _isDescriptionExpanded ? "Show Less" : "Read More",
                                  style: const TextStyle(
                                    color: Color(0xFF9E003F),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: const Color(0xFF9E003F),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text("Opening Hours", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))], color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Text("Daily 09:00 - 18:00 (Closed on Sundays)", style: const TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w300)),
                  ),
                  const SizedBox(height: 30),

                  const Text("Visitors also went to", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))], color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 버튼 위젯 빌더 (activeColor 추가됨)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isActive = false,
    Color activeColor = const Color(0xFF3B82F6), // 기본 활성 색상 (블루)
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75, height: 75,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF9E003F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              // Primary면 흰색, 활성화되면 activeColor, 아니면 회색
              color: isPrimary ? Colors.white : (isActive ? activeColor : Colors.grey[700]),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : (isActive ? activeColor : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}