import 'package:flutter/material.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/core/services/itinerary_service.dart'; // ✅ 서비스 import
import 'package:project1/features/itinerary/widgets/itinerary_card.dart';
import 'package:project1/features/itinerary/pages/itinerary_detail_page.dart';

class ItineraryPublic extends StatefulWidget {
  final int? filterRegionId;
  final String? filterTheme;

  const ItineraryPublic({
    super.key,
    this.filterRegionId,
    this.filterTheme,
  });

  @override
  State<ItineraryPublic> createState() => _ItineraryPublicState();
}

class _ItineraryPublicState extends State<ItineraryPublic> {
  // 서비스 인스턴스
  final _service = ItineraryService();

  // 데이터 및 상태 변수
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;       // 첫 로딩 (전체 화면 로딩)
  bool _isLoadingMore = false;  // 더보기 로딩 (하단 로딩)
  bool _hasMore = true;         // 데이터가 더 있는지 여부
  int _currentPage = 0;         // 현재 페이지
  final int _pageSize = 10;     // 한 번에 가져올 개수

  @override
  void initState() {
    super.initState();
    _loadData(isRefresh: true);
  }

  // 부모(Main)에서 필터 값이 바뀌면 감지해서 새로고침
  @override
  void didUpdateWidget(covariant ItineraryPublic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRegionId != widget.filterRegionId ||
        oldWidget.filterTheme != widget.filterTheme) {
      _loadData(isRefresh: true);
    }
  }

  // 데이터 로딩 함수 (Service 사용)
  Future<void> _loadData({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        if (_itineraries.isEmpty) _isLoading = true; // 데이터가 아예 없을 때만 로딩 표시
        _hasMore = true;
        _currentPage = 0;
        // _itineraries.clear(); // 비우지 않고 덮어쓰기 위해 주석 처리하거나, 로직에 따라 선택
      });
    } else {
      // 더보기 시: 로딩 중이거나 더 없으면 중단
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      // 서비스에게 데이터 요청
      final newItems = await _service.fetchPublicItineraries(
        regionId: widget.filterRegionId,
        theme: widget.filterTheme,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _itineraries = newItems;
          } else {
            _itineraries.addAll(newItems);
          }

          // 더 가져올 게 있는지 확인
          if (newItems.length < _pageSize) {
            _hasMore = false;
          } else {
            _currentPage++;
          }

          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print("Public Load Error: $e");
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_itineraries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _loadData(isRefresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                "No public itineraries found.\nTry changing the filters!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF9E003F),
      onRefresh: () async => _loadData(isRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _itineraries.length + 1,
        itemBuilder: (context, index) {
          // 마지막 아이템: 더보기 버튼
          if (index == _itineraries.length) {
            return _buildLoadMoreButton();
          }

          return ItineraryCard(
            itinerary: _itineraries[index],

            // 클릭 시 상세 페이지 이동 및 복귀 후 자동 업데이트
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItineraryDetailPage(
                    itinerary: _itineraries[index],
                  ),
                ),
              );

              // 돌아왔을 때: 데이터 새로고침
              if (mounted) {
                _loadData(isRefresh: true);
              }
            },

            // 삭제 성공 시 리스트에서 제거
            onDeleteSuccess: () {
              setState(() => _itineraries.removeAt(index));
            },
          );
        },
      ),
    );
  }

  // 하단 더보기 버튼 위젯
  Widget _buildLoadMoreButton() {
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("End of List", style: TextStyle(color: Colors.grey))),
      );
    }

    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: IconButton(
          onPressed: () => _loadData(isRefresh: false), // 더보기 실행
          icon: const Icon(Icons.expand_circle_down_outlined, size: 32, color: Color(0xFF9E003F)),
          tooltip: "Load More",
        ),
      ),
    );
  }
}