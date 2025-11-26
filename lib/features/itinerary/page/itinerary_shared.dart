import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/features/itinerary/widgets/itinerary_card.dart';
import 'package:project1/features/itinerary/pages/itinerary_detail_page.dart';

class ItineraryShared extends StatefulWidget {
  final int? filterRegionId;
  final String? filterTheme;

  const ItineraryShared({
    super.key,
    this.filterRegionId,
    this.filterTheme,
  });

  @override
  State<ItineraryShared> createState() => _ItinerarySharedState();
}

class _ItinerarySharedState extends State<ItineraryShared> {
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  // 부모(Main)에서 필터 값이 바뀌면 감지해서 다시 로딩
  @override
  void didUpdateWidget(covariant ItineraryShared oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRegionId != widget.filterRegionId ||
        oldWidget.filterTheme != widget.filterTheme) {
      _fetchItineraries();
    }
  }

  Future<void> _fetchItineraries({bool isRefresh = false}) async {
    // 새로고침이 아닐 때만 로딩바 표시
    if (!isRefresh) setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      // 1. 기본 쿼리 선택 (작성자, 멤버, 좋아요수, 장소수 포함)
      var query = supabase.from('Itinerary').select(
          '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)');

      // [필터 1] 지역 필터 (Inner Join 사용)
      if (widget.filterRegionId != null) {
        // 지역 필터가 있으면 쿼리를 새로 짭니다 (!inner 사용)
        query = supabase.from('Itinerary').select(
            '*, ItineraryPlace!inner(Place!inner(region_id)), Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)');

        query = query.eq('ItineraryPlace.Place.region_id', widget.filterRegionId!);
      }

      // 2. 공통 조건: Shared
      query = query.eq('post_option', 'shared');

      // [필터 2] 테마 필터
      if (widget.filterTheme != null) {
        query = query.eq('theme', widget.filterTheme!);
      }

      // 3. 정렬 및 실행
      final response = await query.order('created_at', ascending: false);

      // 4. 데이터 처리
      _processData(response);

    } catch (e) {
      print("Shared Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 데이터 처리 헬퍼 함수
  void _processData(List<dynamic> responseData) {
    final newList = responseData.map((json) => Itinerary.fromJson(json)).toList();
    if (mounted) {
      setState(() {
        _itineraries = newList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_itineraries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => await _fetchItineraries(isRefresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                "No shared itineraries found.",
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
      onRefresh: () async => await _fetchItineraries(isRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _itineraries.length,
        itemBuilder: (context, index) {
          return ItineraryCard(
            itinerary: _itineraries[index],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItineraryDetailPage(itinerary: _itineraries[index]),
                ),
              );
              // 돌아왔을 때 데이터 갱신
              if (mounted) _fetchItineraries(isRefresh: true);
            },
            onDeleteSuccess: () {
              setState(() => _itineraries.removeAt(index));
            },
          );
        },
      ),
    );
  }
}