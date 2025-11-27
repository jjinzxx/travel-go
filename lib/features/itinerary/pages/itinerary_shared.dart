import 'package:flutter/material.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/core/services/itinerary_service.dart'; // ✅ 서비스 import
import 'package:project1/features/itinerary/widgets/itinerary_card.dart';
import 'package:project1/features/itinerary/pages/itinerary_detail_page.dart';

class ItineraryShared extends StatefulWidget {
  final int? filterRegionId;
  final String? filterTheme;

  const ItineraryShared({super.key, this.filterRegionId, this.filterTheme});

  @override
  State<ItineraryShared> createState() => _ItinerarySharedState();
}

class _ItinerarySharedState extends State<ItineraryShared> {
  final _service = ItineraryService();

  List<Itinerary> _itineraries = [];

  // 페이징 & 로딩 상태 변수
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData(isRefresh: true);
  }

  @override
  void didUpdateWidget(covariant ItineraryShared oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRegionId != widget.filterRegionId ||
        oldWidget.filterTheme != widget.filterTheme) {
      _loadData(isRefresh: true);
    }
  }

  // 📡 데이터 로딩 (Service 사용)
  Future<void> _loadData({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
        _currentPage = 0;
        _itineraries.clear();
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      // Service의 fetchSharedItineraries 호출
      final newItems = await _service.fetchSharedItineraries(
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
      print("Shared Load Error: $e");
      if (mounted)
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
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
                "No shared itineraries found.\nInvite friends to edit together!",
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
        itemCount: _itineraries.length + 1, // 더보기 버튼 포함
        itemBuilder: (context, index) {
          if (index == _itineraries.length) {
            return _buildLoadMoreButton();
          }

          return ItineraryCard(
            itinerary: _itineraries[index],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ItineraryDetailPage(itinerary: _itineraries[index]),
                ),
              );
              // 상세 페이지 복귀 시 데이터 갱신
              if (mounted) _loadData(isRefresh: true);
            },
            onDeleteSuccess: () {
              setState(() => _itineraries.removeAt(index));
            },
          );
        },
      ),
    );
  }

  // 하단 더보기 버튼
  Widget _buildLoadMoreButton() {
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text("End of List", style: TextStyle(color: Colors.grey)),
        ),
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
