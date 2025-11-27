import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';

class ItineraryService {
  final supabase = Supabase.instance.client;

  // 1. Public 여행 목록 가져오기
  Future<List<Itinerary>> fetchPublicItineraries({
    int? regionId,
    String? theme,
    int page = 0,
    int pageSize = 10,
  }) async {
    try {
      String selectQuery =
          '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)';

      if (regionId != null) {
        selectQuery =
        '*, ItineraryPlace!inner(Place!inner(region_id)), Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)';
      }

      // 1. 여기서 query 변수는 '필터' 역할만 합니다.
      var query = supabase.from('Itinerary').select(selectQuery);

      // 2. 필터 조건들 추가 (query 변수 재사용 가능 - 같은 필터 타입이라서)
      query = query.eq('post_option', 'public');

      if (regionId != null) {
        query = query.eq('ItineraryPlace.Place.region_id', regionId);
      }

      if (theme != null) {
        query = query.eq('theme', theme);
      }

      // 3. [수정된 부분] 정렬과 페이징은 query에 다시 담지 않고, 실행할 때 바로 붙입니다!
      // (이유: order를 쓰면 타입이 변하기 때문)
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response = await query
          .order('post_like', ascending: false) // 좋아요 많은 순
          .order('created_at', ascending: false) // 최신 순
          .range(from, to); // 페이징

      // 4. 변환 및 반환
      final data = response as List<dynamic>;
      return data.map((json) => Itinerary.fromJson(json)).toList();

    } catch (e) {
      throw Exception('Public 리스트 로딩 실패: $e');
    }
  }

  // Shared 여행 목록 가져오기
  Future<List<Itinerary>> fetchSharedItineraries({
    int? regionId,
    String? theme,
    int page = 0,
    int pageSize = 10,
  }) async {
    try {
      String selectQuery =
          '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)';

      if (regionId != null) {
        selectQuery =
        '*, ItineraryPlace!inner(Place!inner(region_id)), Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)';
      }

      var query = supabase.from('Itinerary').select(selectQuery);

      // 조건: Shared
      query = query.eq('post_option', 'shared');

      // [필터] 지역
      if (regionId != null) {
        query = query.eq('ItineraryPlace.Place.region_id', regionId);
      }
      // [필터] 테마
      if (theme != null) {
        query = query.eq('theme', theme);
      }
      // [정렬] 좋아요 순 -> 최신 순
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response = await query
          .order('post_like', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to);

      final data = response as List<dynamic>;
      return data.map((json) => Itinerary.fromJson(json)).toList();

    } catch (e) {
      throw Exception('Shared 리스트 로딩 실패: $e');
    }
  }

  // Private 여행 목록 가져오기
  Future<List<Itinerary>> fetchPrivateItineraries({
    required String userId, // 내 ID 필수
    int? regionId,
    String? theme,
    int page = 0,
    int pageSize = 10,
  }) async {
    try {
      // 1. 내가 초대된(멤버인) 여행 ID 목록 먼저 조회
      final memberRes = await supabase
          .from('ItineraryMember')
          .select('itinerary_id')
          .eq('user_id', userId);

      final List<int> invitedIds = (memberRes as List)
          .map((e) => e['itinerary_id'] as int)
          .toList();

      // 2. 쿼리 작성
      String selectQuery =
          '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)';

      if (regionId != null) {
        selectQuery =
        '*, ItineraryPlace!inner(Place!inner(region_id)), Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)';
      }

      var query = supabase.from('Itinerary').select(selectQuery);

      // [필터] 지역
      if (regionId != null) {
        query = query.eq('ItineraryPlace.Place.region_id', regionId);
      }
      // [필터] 테마
      if (theme != null) {
        query = query.eq('theme', theme);
      }
      // [필터] Private 조건
      query = query.eq('post_option', 'private');

      // [권한] 작성자 본인 OR 초대된 리스트에 포함
      if (invitedIds.isEmpty) {
        query = query.eq('user_id', userId);
      } else {
        final idsString = invitedIds.join(',');
        // .or()는 앞의 조건들과 AND로 결합됩니다.
        query = query.or('user_id.eq.$userId, itinerary_id.in.($idsString)');
      }

      // [정렬 & 페이징]
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response = await query
          .order('post_like', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to);

      final data = response as List<dynamic>;
      return data.map((json) => Itinerary.fromJson(json)).toList();

    } catch (e) {
      throw Exception('Private 리스트 로딩 실패: $e');
    }
  }

  // 2. 수정 (UPDATE): 이미지 URL 처리 포함
  Future<void> updateItinerary({
    required int itineraryId,
    required String title,
    required String description,
    required String theme,
    required DateTime startDate,
    required DateTime endDate,
    required String postOption,
    required String? coverImageUrl, // 수정된 이미지 URL
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'title': title,
        'description': description,
        'theme': theme,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'post_option': postOption,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 이미지가 변경되었을 때만 업데이트 목록에 추가
      if (coverImageUrl != null) {
        updates['Itinerary_image_url'] = coverImageUrl;
      }

      await supabase.from('Itinerary').update(updates).eq('itinerary_id', itineraryId);
    } catch (e) {
      throw Exception('일정 수정 실패: $e');
    }
  }

  // 3. 이미지 업로드 (UPLOAD)
  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final path = 'covers/$fileName';

      await supabase.storage.from('itinerary_covers').upload(path, imageFile);

      final imageUrl = supabase.storage.from('itinerary_covers').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  // 4. 생성 (CREATE)
  Future<void> createItinerary({
    required String userId,
    required String title,
    required String description,
    required String theme,
    required DateTime startDate,
    required DateTime endDate,
    required String postOption,
    required String? coverImageUrl,
  }) async {
    try {
      await supabase.from('Itinerary').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'theme': theme,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'post_option': postOption,
        'Itinerary_image_url': coverImageUrl,
        'post_like': 0, // 초기 좋아요 0
      });
    } catch (e) {
      throw Exception('일정 생성 실패: $e');
    }
  }

  // 5. 삭제 (DELETE)
  Future<void> deleteItinerary(int itineraryId) async {
    try {
      await supabase.from('Itinerary').delete().eq('itinerary_id', itineraryId);
    } catch (e) {
      throw Exception('일정 삭제 실패: $e');
    }
  }

  // 6. 조회수 증가 (RPC 함수 호출)
  Future<void> incrementViewCount(int itineraryId) async {
    try {
      await supabase.rpc('increment_view_count', params: {
        'row_id': itineraryId,
      });
    } catch (e) {
      // 조회수 증가는 실패해도 사용자에게 에러를 띄울 필요는 없음 (로그만 남김)
      print("조회수 증가 실패: $e");
    }
  }

  // --- [Detail Page Logic] ---

  // 장소 목록 가져오기
  Future<List<ItineraryItem>> fetchPlaces(int itineraryId) async {
    try {
      final response = await supabase
          .from('ItineraryPlace')
          .select('*, Place(*), ItineraryDay(day_num)')
          .eq('itinerary_id', itineraryId)
          .order('route_id', ascending: true);

      final data = response as List<dynamic>;
      return data.map((json) => ItineraryItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('장소 로딩 실패: $e');
    }
  }

  // 장소 추가
  Future<void> addPlaceToItinerary({
    required int itineraryId,
    required int placeId,
    required int dayNum,
  }) async {
    try {
      // Day ID 확인/생성 로직
      final dayRes = await supabase.from('ItineraryDay')
          .select().eq('itinerary_id', itineraryId).eq('day_num', dayNum).maybeSingle();

      int dayId;
      if (dayRes != null) {
        dayId = dayRes['day_id'];
      } else {
        final newDay = await supabase.from('ItineraryDay')
            .insert({'itinerary_id': itineraryId, 'day_num': dayNum})
            .select().single();
        dayId = newDay['day_id'];
      }

      await supabase.from('ItineraryPlace').insert({
        'itinerary_id': itineraryId,
        'place_id': placeId,
        'day_id': dayId,
      });
    } catch (e) {
      throw Exception('장소 추가 실패: $e');
    }
  }

  // 장소 삭제
  Future<void> deletePlace(int routeId) async {
    try {
      await supabase.from('ItineraryPlace').delete().eq('route_id', routeId);
    } catch (e) {
      throw Exception('장소 삭제 실패: $e');
    }
  }

  // 좋아요 정보 가져오기 (count, isLiked)
  Future<Map<String, dynamic>> fetchLikeInfo(int itineraryId, String? userId) async {
    try {
      final count = await supabase.from('ItineraryLikes').count(CountOption.exact).eq('itinerary_id', itineraryId);
      bool isLiked = false;
      if (userId != null) {
        final myLike = await supabase.from('ItineraryLikes').select().eq('itinerary_id', itineraryId).eq('user_id', userId).maybeSingle();
        isLiked = myLike != null;
      }
      return {'count': count, 'isLiked': isLiked};
    } catch (e) {
      throw Exception('좋아요 정보 로딩 실패: $e');
    }
  }

  // 좋아요 토글
  Future<void> toggleLike(int itineraryId, String userId, bool isLiked) async {
    try {
      if (isLiked) {
        // 이미 좋아요 상태 -> 취소(삭제)
        await supabase.from('ItineraryLikes').delete().match({'user_id': userId, 'itinerary_id': itineraryId});
      } else {
        // 좋아요 안 한 상태 -> 추가
        await supabase.from('ItineraryLikes').insert({'user_id': userId, 'itinerary_id': itineraryId});
      }
    } catch (e) {
      throw Exception('좋아요 처리 실패: $e');
    }
  }

  // 일정 복사
  Future<void> copyItinerary(int sourceId, String userId) async {
    try {
      await supabase.rpc('copy_itinerary', params: {
        'source_itinerary_id': sourceId,
        'new_owner_id': userId,
      });
    } catch (e) {
      throw Exception('복사 실패: $e');
    }
  }

  // 멤버 초대
  Future<void> inviteMember(int itineraryId, String targetUserId) async {
    await supabase.from('ItineraryMember').insert({
      'itinerary_id': itineraryId,
      'user_id': targetUserId,
      'role': 'editor',
    });
  }

  // 유저 검색
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final res = await supabase.from('Users').select().ilike('name', '%$query%').limit(5);
    return List<Map<String, dynamic>>.from(res);
  }

  // 장소 검색
  Future<List<Place>> searchPlaces(String query) async {
    final res = await supabase.from('Place').select().or('name_kr.ilike.%$query%, name_en.ilike.%$query%').limit(10);
    final data = res as List<dynamic>;
    return data.map((json) => Place.fromJson(json)).toList();
  }


}