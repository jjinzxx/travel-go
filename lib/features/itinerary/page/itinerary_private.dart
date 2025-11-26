import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/features/itinerary/widgets/itinerary_card.dart';
import 'package:project1/features/itinerary/pages/itinerary_detail_page.dart';

class ItineraryPrivate extends StatefulWidget {
  final int? filterRegionId;
  final String? filterTheme;

  const ItineraryPrivate({
    super.key,
    this.filterRegionId,
    this.filterTheme,
  });

  @override
  State<ItineraryPrivate> createState() => _ItineraryPrivateState();
}

class _ItineraryPrivateState extends State<ItineraryPrivate> {
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  // 부모(Main)에서 필터 값이 바뀌면 감지
  @override
  void didUpdateWidget(covariant ItineraryPrivate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRegionId != widget.filterRegionId ||
        oldWidget.filterTheme != widget.filterTheme) {
      _fetchItineraries();
    }
  }

  Future<void> _fetchItineraries({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // 로그인 안 했으면 Private은 볼 수 없음
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. 내가 '멤버'로 초대된 여행들의 ID 리스트 가져오기
      final memberRes = await supabase
          .from('ItineraryMember')
          .select('itinerary_id')
          .eq('user_id', user.id);

      final List<int> invitedIds = (memberRes as List)
          .map((e) => e['itinerary_id'] as int)
          .toList();

      // 2. 기본 쿼리 빌드
      var query = supabase.from('Itinerary').select(
          '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)');

      // [필터 1] 지역 필터 (Inner Join)
      if (widget.filterRegionId != null) {
        query = supabase.from('Itinerary').select(
            '*, ItineraryPlace!inner(Place!inner(region_id)), Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)');

        query = query.eq('ItineraryPlace.Place.region_id', widget.filterRegionId!);
      }

      // 3. 공통 조건: Private
      query = query.eq('post_option', 'private');

      // [필터 2] 테마 필터
      if (widget.filterTheme != null) {
        query = query.eq('theme', widget.filterTheme!);
      }

      // [권한 필터] (작성자가 나 OR 초대된 리스트에 포함)
      if (invitedIds.isEmpty) {
        query = query.eq('user_id', user.id);
      } else {
        final idsString = invitedIds.join(',');
        query = query.or('user_id.eq.${user.id}, itinerary_id.in.($idsString)');
      }

      // 4. 실행 및 데이터 변환
      final response = await query.order('created_at', ascending: false);
      _processData(response);

    } catch (e) {
      print("Private Error: $e");
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
                "No private itineraries found.\nCreate your own trip!",
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