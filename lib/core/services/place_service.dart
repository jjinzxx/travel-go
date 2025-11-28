import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';

class PlaceService {
  final supabase = Supabase.instance.client;

  // [Save] 장소 찜하기 토글 (SavedPlaces 테이블)
  // regionId가 필수(NOT NULL)이므로 인자로 받아야 합니다.
  Future<bool> toggleSave(int placeId, int regionId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Login required');

    try {
      // 1. 이미 저장했는지 확인
      final existing = await supabase
          .from('SavedPlaces')
          .select()
          .eq('user_id', userId)
          .eq('place_id', placeId)
          .maybeSingle();

      if (existing != null) {
        // 2. 이미 있으면 삭제 (Unsave) - 복합키라 match 사용
        await supabase.from('SavedPlaces').delete().match({
          'user_id': userId,
          'place_id': placeId,
        });
        return false; // 저장 해제됨
      } else {
        // 3. 없으면 추가 (Save) - region_id 필수 포함
        await supabase.from('SavedPlaces').insert({
          'user_id': userId,
          'place_id': placeId,
          'region_id': regionId,
        });
        return true; // 저장됨
      }
    } catch (e) {
      throw Exception('저장 실패: $e');
    }
  }

  // 장소 좋아요 토글 (LikedPlaces 테이블)
  Future<bool> toggleLike(int placeId, int regionId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Login required');

    try {
      final existing = await supabase
          .from('LikedPlaces')
          .select()
          .eq('user_id', userId)
          .eq('place_id', placeId)
          .maybeSingle();

      if (existing != null) {
        // 삭제 (Unlike)
        await supabase.from('LikedPlaces').delete().match({
          'user_id': userId,
          'place_id': placeId,
        });
        return false;
      } else {
        // 추가 (Like) - region_id는 nullable이지만 넣어주는 게 좋음
        await supabase.from('LikedPlaces').insert({
          'user_id': userId,
          'place_id': placeId,
          'region_id': regionId,
        });
        return true;
      }
    } catch (e) {
      throw Exception('좋아요 실패: $e');
    }
  }

  // 초기 상태 확인
  Future<Map<String, bool>> fetchPlaceStatus(int placeId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return {'isSaved': false, 'isLiked': false};

    // SavedPlaces 확인
    final saved = await supabase.from('SavedPlaces').select().eq('user_id', userId).eq('place_id', placeId).maybeSingle();
    // LikedPlaces 확인
    final liked = await supabase.from('LikedPlaces').select().eq('user_id', userId).eq('place_id', placeId).maybeSingle();

    return {
      'isSaved': saved != null,
      'isLiked': liked != null,
    };
  }

  // 내가 저장하거나 좋아요한 장소 가져오기
  Future<List<Place>> fetchMyBookmarkedPlaces(String userId) async {
    try {
      // 1. SavedPlaces (저장한 곳) 가져오기
      final savedRes = await supabase
          .from('SavedPlaces')
          .select('Place(*)') // 연결된 Place 정보 가져오기
          .eq('user_id', userId);

      // 2. LikedPlaces (좋아요한 곳) 가져오기
      final likedRes = await supabase
          .from('LikedPlaces')
          .select('Place(*)') // 연결된 Place 정보 가져오기
          .eq('user_id', userId);

      // 3. 두 리스트 합치기 & 중복 제거
      // (Place ID를 키로 사용하여 중복을 없앱니다)
      final Map<int, Place> placeMap = {};

      // 저장한 장소 파싱
      for (var item in savedRes as List) {
        if (item['Place'] != null) {
          final place = Place.fromJson(item['Place']);
          placeMap[place.id] = place;
        }
      }

      // 좋아요한 장소 파싱 (이미 있으면 덮어씌우거나 무시)
      for (var item in likedRes as List) {
        if (item['Place'] != null) {
          final place = Place.fromJson(item['Place']);
          placeMap[place.id] = place; // ID가 같으면 덮어씀 (상관없음)
        }
      }

      // 리스트로 변환하여 반환
      return placeMap.values.toList();

    } catch (e) {
      throw Exception('내 장소 불러오기 실패: $e');
    }
  }

}