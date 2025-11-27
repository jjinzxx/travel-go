// 1. 작성자 정보 (User 테이블 매핑)
class Author {
  final String name;
  final String? profileImage;

  Author({required this.name, this.profileImage});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      // DB 컬럼명: name (또는 nickname), profile_image_url
      name: json['name'] ?? json['nickname'] ?? 'Unknown User',
      profileImage: json['profile_image_url'],
    );
  }
}

// 2. 메인 여행 일정 (Itinerary 테이블 매핑)
class Itinerary {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final String? coverImageUrl; // 이미지 URL
  final DateTime? startDate;
  final DateTime? endDate;
  final String? theme;
  final int viewCount;
  final int likeCount;         // 좋아요 수 (post_like)
  final int placeCount;        // 장소 수 (ItineraryPlace 카운트)
  final String postOption;     // 'public', 'shared', 'private'
  final Author? author;        // 작성자 정보
  final List<Author> members;  // 참여 멤버 리스트

  Itinerary({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.startDate,
    this.endDate,
    this.theme,
    this.viewCount = 0,
    this.likeCount = 0,
    this.placeCount = 0,
    required this.postOption,
    this.author,
    this.members = const [],
  });

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    // 멤버 리스트 파싱 (ItineraryMember -> Users Join 결과)
    var membersList = <Author>[];
    if (json['ItineraryMember'] != null) {
      membersList = (json['ItineraryMember'] as List).map((m) {
        // ItineraryMember 안에 nested된 Users 정보를 가져옴
        return Author.fromJson(m['Users']);
      }).toList();
    }

    return Itinerary(
      id: json['itinerary_id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      description: json['description'],

      // DB 컬럼명: Itinerary_image_url
      coverImageUrl: json['Itinerary_image_url'],

      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      theme: json['theme'],
      viewCount: json['view_count'] ?? 0,

      // DB 컬럼명: post_like (기본값 0)
      likeCount: json['post_like'] ?? 0,

      // 장소 개수 (Count 쿼리 결과: [{'count': 5}])
      placeCount: (json['ItineraryPlace'] as List?)?.isNotEmpty == true
          ? json['ItineraryPlace'][0]['count'] as int
          : 0,

      postOption: json['post_option'] ?? 'private',

      // 작성자 정보 매핑
      author: json['Users'] != null ? Author.fromJson(json['Users']) : null,
      members: membersList,
    );
  }
}

// 3. 순수한 장소 정보 (Place 테이블 매핑)
class Place {
  final int id;
  final String name; // 화면 표시용 대표 이름
  final String? nameKr;
  final String? nameEn;
  final String? description;
  final String? descriptionEn;
  final String? descriptionKr;
  final String? category;

  Place({
    required this.id,
    required this.name,
    this.nameKr,
    this.nameEn,
    this.description,
    this.descriptionEn,
    this.descriptionKr,
    this.category,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    // 이름 우선순위: 영어 > 한글 > 기본 name > Unknown
    final englishName = json['name_en'] as String?;
    final koreanName = json['name_kr'] as String?;
    final defaultName = json['name'] as String?;

    return Place(
      id: json['place_id'],
      name: englishName ?? koreanName ?? defaultName ?? 'Unknown Place',
      nameKr: koreanName,
      nameEn: englishName,
      description: json['description_en'] ?? json['description_kr'] ?? json['description'] ?? 'No description',
      descriptionEn: json['description_en'],
      descriptionKr: json['description_kr'],
      category: json['category'],
    );
  }
}

// 4. 일정에 등록된 장소 항목 (ItineraryPlace 테이블 + Join된 Place)
class ItineraryItem {
  final int routeId;      // ItineraryPlace PK
  final int itineraryId;
  final Place? place;     // 장소 정보 객체
  final int dayId;
  final int dayNum;       // 몇 일차인지 (1, 2, 3...)

  ItineraryItem({
    required this.routeId,
    required this.itineraryId,
    this.place,
    required this.dayId,
    this.dayNum = 1,
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    // ItineraryDay와 Join되어 있다면 day_num을 가져옴
    int parsedDayNum = 1;
    if (json['ItineraryDay'] != null) {
      parsedDayNum = json['ItineraryDay']['day_num'] ?? 1;
    }

    return ItineraryItem(
      routeId: json['route_id'],
      itineraryId: json['itinerary_id'],
      dayId: json['day_id'] ?? 1,
      dayNum: parsedDayNum,
      // Place 정보 매핑
      place: json['Place'] != null ? Place.fromJson(json['Place']) : null,
    );
  }
}

// 5. 지역 정보 (Region 테이블 매핑)
class Region {
  final int id;
  final String nameEn;
  final String? nameKr;

  Region({required this.id, required this.nameEn, this.nameKr});

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['region_id'],
      nameEn: json['city_name_en'],
      nameKr: json['city_name_kr'],
    );
  }
}