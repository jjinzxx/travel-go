import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItineraryService {
  final supabase = Supabase.instance.client;

  // 여행 일정 수정하기 (Update)
  Future<void> updateItinerary({
    required int itineraryId,
    required String title,
    required String description,
    required String theme,
    required DateTime startDate,
    required DateTime endDate,
    required String postOption,
    required String? coverImageUrl,
  }) async {
    try {
      // 1. 업데이트할 기본 데이터 맵 생성
      final Map<String, dynamic> updates = {
        'title': title,
        'description': description,
        'theme': theme,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'post_option': postOption,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 2. 이미지가 변경되었을 때만(null이 아닐 때만) 이미지 컬럼도 업데이트 목록에 추가
      if (coverImageUrl != null) {
        updates['Itinerary_image_url'] = coverImageUrl;
      }

      // 3. DB 업데이트 실행
      await supabase.from('Itinerary').update(updates).eq('itinerary_id', itineraryId);

    } catch (e) {
      throw Exception('일정 수정 실패: $e');
    }
  }

  // 이미지 업로드 함수
  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final path = 'covers/$fileName';

      // 1. Storage에 업로드
      await supabase.storage.from('itinerary_covers').upload(path, imageFile);

      // 2. 공개 URL 가져오기
      final imageUrl = supabase.storage.from('itinerary_covers').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  // 여행 일정 생성 함수
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
      });
    } catch (e) {
      throw Exception('일정 생성 실패: $e');
    }
  }

  // 여행 일정 삭제하기 (Delete)
  Future<void> deleteItinerary(int itineraryId) async {
    try {
      await supabase.from('Itinerary').delete().eq('itinerary_id', itineraryId);
    } catch (e) {
      throw Exception('일정 삭제 실패: $e');
    }
  }
}
