import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';
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
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  // 필터 값이 바뀌면 감지해서 데이터 다시 로드
  @override
  void didUpdateWidget(covariant ItineraryPublic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRegionId != widget.filterRegionId ||
        oldWidget.filterTheme != widget.filterTheme) {
      _fetchItineraries();
    }
  }

  Future<void> _fetchItineraries({bool isRefresh = false}) async {
    // 새로고침이 아닐 때만 로딩바 표시 (Silent Refresh)
    if (!isRefresh) setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      // [필터 1] 지역 필터 (Inner Join 사용)
      // 지역 필터가 있으면 ItineraryPlace와 Place를 거쳐서 필터링해야 하므로 쿼리가 다릅니다.
      if (widget.filterRegionId != null) {
        final response = await supabase
            .from('Itinerary')
            .select(
          // !inner: 조건에 맞는 자식 데이터가 있는 부모만 가져옴
            '*, ItineraryPlace!inner(Place!inner(region_id)), Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)'
        )
            .eq('post_option', 'public') // Public 조건
            .eq(
            'ItineraryPlace.Place.region_id', widget.filterRegionId!) // 지역 조건
        // 테마 필터가 있다면 여기서 같이 적용
            .match(
            widget.filterTheme != null ? {'theme': widget.filterTheme!} : {})
            .order('created_at', ascending: false);

        _processData(response);
        return; // 지역 필터 로직 끝
      }

      // [일반 조회] 지역 필터가 없을 때
      var query = supabase.from('Itinerary').select(
          '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)');

      // 공통 조건: Public
      query = query.eq('post_option', 'public');

      // [필터 2] 테마 필터
      if (widget.filterTheme != null) {
        query = query.eq('theme', widget.filterTheme!);
      }

      // 실행
      final response = await query.order('created_at', ascending: false);
      _processData(response);
    } catch (e) {
      print("Public Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 데이터 처리 헬퍼 함수
  void _processData(List<dynamic> responseData) {
    final newList = responseData
        .map((json) => Itinerary.fromJson(json))
        .toList();
    if (mounted) {
      setState(() {
        _itineraries = newList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. 로딩 중
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. 데이터 없음
    if (_itineraries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => await _fetchItineraries(isRefresh: true),
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

    // 3. 리스트 출력
    return RefreshIndicator(
      color: const Color(0xFF9E003F),
      onRefresh: () async => await _fetchItineraries(isRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _itineraries.length,
        itemBuilder: (context, index) {
          return ItineraryCard(
            itinerary: _itineraries[index],

            // 클릭 시 상세 페이지 이동
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ItineraryDetailPage(itinerary: _itineraries[index]),
                ),
              );
              // 상세 페이지에서 돌아오면 데이터 갱신 (좋아요, 조회수 등)
              if (mounted) _fetchItineraries(isRefresh: true);
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
}