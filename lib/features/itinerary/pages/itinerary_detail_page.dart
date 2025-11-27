import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/core/services/itinerary_service.dart'; // ✅ 서비스 import
import 'package:project1/features/itinerary/pages/itinerary_modify_page.dart';

class ItineraryDetailPage extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryDetailPage({super.key, required this.itinerary});

  @override
  State<ItineraryDetailPage> createState() => _ItineraryDetailPageState();
}

class _ItineraryDetailPageState extends State<ItineraryDetailPage> {
  // ✅ 서비스 인스턴스
  final _service = ItineraryService();

  late Itinerary _itinerary;

  // 상태 변수
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = false;
  List<ItineraryItem> _allPlaces = [];
  bool _isPlacesLoading = true;
  int _totalDays = 1;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _itinerary = widget.itinerary;
    _calculateTotalDays();

    // 초기 데이터 로딩
    _fetchLikeInfo();
    _fetchPlaces();
    _checkAuthority();

    // 조회수 증가 요청
    _service.incrementViewCount(_itinerary.id);
  }

  // --- [Logic Section (Service 호출로 변경됨)] ---

  // 여행 기간 계산
  void _calculateTotalDays() {
    if (_itinerary.startDate != null && _itinerary.endDate != null) {
      final start = _itinerary.startDate!;
      final end = _itinerary.endDate!;
      final diff = end.difference(start).inDays + 1;
      setState(() {
        _totalDays = diff > 0 ? diff : 1;
      });
    }
  }

  // 권한 확인
  Future<void> _checkAuthority() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (myId == null) {
      if (mounted) setState(() => _canEdit = false);
      return;
    }
    // 작성자이거나 Public이면 수정 가능 (정책에 따라 Public은 제외 가능)
    if (_itinerary.userId == myId || _itinerary.postOption == 'public') {
      if (mounted) setState(() => _canEdit = true);
      return;
    }

    // 멤버인지 확인
    try {
      // (간단한 조회라 직접 호출 유지)
      final response = await Supabase.instance.client
          .from('ItineraryMember')
          .select()
          .eq('itinerary_id', _itinerary.id)
          .eq('user_id', myId)
          .maybeSingle();
      if (mounted) setState(() => _canEdit = response != null);
    } catch (e) {
      print("권한 확인 에러: $e");
    }
  }

  // 수정 후 데이터 새로고침
  Future<void> _refetchItineraryDetail() async {
    try {
      // 서비스에 fetchDetail 함수가 있다면 그걸 써도 되지만, 여기선 직접 조회 유지
      final response = await Supabase.instance.client
          .from('Itinerary')
          .select(
            '*, Users(name, profile_image_url), ItineraryMember(Users(name, profile_image_url)), ItineraryLikes(count), ItineraryPlace(count)',
          )
          .eq('itinerary_id', _itinerary.id)
          .single();

      if (mounted) {
        setState(() {
          _itinerary = Itinerary.fromJson(response);
          _calculateTotalDays();
        });
      }
    } catch (e) {
      print("Refetch Error: $e");
    }
  }

  // 장소 가져오기 (Service)
  Future<void> _fetchPlaces() async {
    try {
      final places = await _service.fetchPlaces(_itinerary.id);
      if (mounted) {
        setState(() {
          _allPlaces = places;
          _isPlacesLoading = false;
        });
      }
    } catch (e) {
      print('Fetch Places Error: $e');
      if (mounted) setState(() => _isPlacesLoading = false);
    }
  }

  // 장소 추가 (Service)
  Future<void> _addPlaceToItinerary(Place place, int targetDayNum) async {
    try {
      await _service.addPlaceToItinerary(
        itineraryId: _itinerary.id,
        placeId: place.id,
        dayNum: targetDayNum,
      );

      await _fetchPlaces(); // 리스트 갱신

      if (mounted) {
        Navigator.pop(context); // 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'${place.name}' added to Day $targetDayNum!"),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 장소 삭제 (Service)
  Future<void> _deletePlace(int routeId) async {
    try {
      await _service.deletePlace(routeId);

      setState(() {
        _allPlaces.removeWhere((item) => item.routeId == routeId);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Place removed.")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  // 좋아요 정보 로드 (Service)
  Future<void> _fetchLikeInfo() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final info = await _service.fetchLikeInfo(_itinerary.id, userId);
      if (mounted) {
        setState(() {
          _likeCount = info['count'];
          _isLiked = info['isLiked'];
        });
      }
    } catch (e) {
      print('Fetch Like Error: $e');
    }
  }

  // 좋아요 토글 (Service)
  Future<void> _toggleLike() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You need to log in.')));
      return;
    }
    if (_isLikeLoading) return;

    // UI 선반영 (Optimistic Update)
    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      await _service.toggleLike(
        _itinerary.id,
        userId,
        !_isLiked,
      ); // 현재 상태의 반대로 요청
    } catch (e) {
      // 실패 시 롤백
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      print('Toggle Like Error: $e');
    } finally {
      setState(() => _isLikeLoading = false);
    }
  }

  // 일정 복사 (Service)
  Future<void> _copyItinerary() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please log in to copy.")));
      return;
    }
    try {
      await _service.copyItinerary(_itinerary.id, userId);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Copied to Private tab!")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Copy failed: $e")));
    }
  }

  // 장소 검색 (Service)
  Future<void> _searchPlaces(
    String query,
    Function(List<Place>) onResult,
  ) async {
    try {
      final places = await _service.searchPlaces(query);
      onResult(places);
    } catch (e) {
      onResult([]);
    }
  }

  // 멤버 초대 (Service)
  Future<void> _inviteUser(String targetUserId, String targetNickname) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (targetUserId == myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot invite yourself.")),
      );
      return;
    }
    try {
      await _service.inviteMember(_itinerary.id, targetUserId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$targetNickname invited!")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Invite failed: $e")));
    }
  }

  // --- [Dialogs Section] ---

  void _showAddPlaceDialog(int dayNum) {
    final searchController = TextEditingController();
    List<Place> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Container(
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add Place to Day $dayNum",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: "Search places...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) async {
                              if (searchController.text.isEmpty) return;
                              setModalState(() => isSearching = true);
                              await _searchPlaces(searchController.text, (
                                results,
                              ) {
                                setModalState(() {
                                  searchResults = results;
                                  isSearching = false;
                                });
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (searchController.text.isEmpty) return;
                            setModalState(() => isSearching = true);
                            await _searchPlaces(searchController.text, (
                              results,
                            ) {
                              setModalState(() {
                                searchResults = results;
                                isSearching = false;
                              });
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Search",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final place = searchResults[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.place,
                                      color: Color(0xFF9E003F),
                                    ),
                                  ),
                                  title: Text(
                                    (place.nameEn != null &&
                                            place.nameKr != null)
                                        ? "${place.nameEn} (${place.nameKr})"
                                        : place.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    place.category ??
                                        place.description ??
                                        "No details",
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Color(0xFF9E003F),
                                    ),
                                    onPressed: () =>
                                        _addPlaceToItinerary(place, dayNum),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInviteMemberDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Container(
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Invite Member",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: "Search by name...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (searchController.text.isEmpty) return;
                            setModalState(() => isSearching = true);
                            final res = await _service.searchUsers(
                              searchController.text,
                            );
                            setModalState(() {
                              searchResults = res;
                              isSearching = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Search",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final user = searchResults[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        user['profile_image_url'] != null
                                        ? NetworkImage(
                                            user['profile_image_url'],
                                          )
                                        : null,
                                    child: user['profile_image_url'] == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(user['name'] ?? "Unknown"),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.person_add,
                                      color: Color(0xFF9E003F),
                                    ),
                                    onPressed: () => _inviteUser(
                                      user['user_id'],
                                      user['name'],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- [UI Section (디자인 유지)] ---

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDateRange(_itinerary.startDate, _itinerary.endDate);
    final isPublic = _itinerary.postOption == 'public';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == _itinerary.userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // 1. 상단 헤더
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (isOwner)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    icon: const Icon(Icons.edit, color: Color(0xFF9e003f)),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ItineraryModifyPage(itinerary: _itinerary),
                        ),
                      );
                      if (result == true) {
                        await _refetchItineraryDetail();
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Itinerary updated!")),
                          );
                      }
                    },
                  ),
                ),
              const SizedBox(width: 4),
              if (isOwner && !isPublic)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: Color(0xFF9e003f),
                    ),
                    onPressed: _showInviteMemberDialog,
                  ),
                ),
              const SizedBox(width: 4),
              Container(
                margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPublic ? Icons.language : Icons.lock,
                      size: 16,
                      color: const Color(0xFF9E003F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _itinerary.postOption.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF9E003F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _itinerary.coverImageUrl != null
                      ? Image.network(
                          _itinerary.coverImageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.grey),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itinerary.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildAvatar(_itinerary.author?.profileImage),
                              const SizedBox(width: 8),
                              Text(
                                _itinerary.author?.name ?? "Unknown",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              if (_itinerary.members.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 12),
                                ..._itinerary.members
                                    .take(4)
                                    .map(
                                      (member) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: _buildAvatar(
                                          member.profileImage,
                                        ),
                                      ),
                                    ),
                                if (_itinerary.members.length > 4)
                                  Text(
                                    "+${_itinerary.members.length - 4}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 설명 및 버튼
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTag(Icons.calendar_today, dateStr, isPink: true),
                      const SizedBox(width: 12),
                      if (_itinerary.theme != null)
                        _buildTag(null, _itinerary.theme!, isPink: false),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _itinerary.description ?? "No description.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.near_me,
                          label: "Navigate",
                          color: const Color(0xFF9E003F),
                          textColor: Colors.white,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: _isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: "$_likeCount",
                          color: Colors.white,
                          textColor: _isLiked ? Colors.red : Colors.grey[700]!,
                          onTap: _toggleLike,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.copy,
                          label: "Copy",
                          color: Colors.white,
                          textColor: Colors.grey[700]!,
                          onTap: _copyItinerary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Day 리스트
          for (int day = 1; day <= _totalDays; day++) ...[
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Row(
                  children: [
                    Text(
                      "Day $day",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_canEdit)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF9E003F),
                          ),
                          onPressed: () => _showAddPlaceDialog(day),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final dayPlaces = _allPlaces
                    .where((p) => p.dayNum == day)
                    .toList();
                if (dayPlaces.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.only(left: 20, bottom: 20),
                      child: Text(
                        "No places planned yet.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = dayPlaces[index];
                    if (_canEdit) {
                      return Dismissible(
                        key: ValueKey(item.routeId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Color(0xFF9E003F),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deletePlace(item.routeId),
                        child: _buildPlaceItemWrapper(index + 1, item),
                      );
                    }
                    return _buildPlaceItemWrapper(index + 1, item);
                  }, childCount: dayPlaces.length),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPlaceDialog(1), // 기본 Day 1 추가
              backgroundColor: const Color(0xFF9E003F),
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text(
                "Add Place",
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  // --- [Helper Widgets (디자인 유지)] ---

  Widget _buildPlaceItemWrapper(int index, ItineraryItem item) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _buildPlaceItem(
        index,
        item.place?.name ?? "Unknown Place",
        item.place?.description ?? "No description",
      ),
    );
  }

  Widget _buildPlaceItem(int index, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Text(
              "$index",
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData? icon, String text, {required bool isPink}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPink ? const Color(0xFFFFF0F5) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: const Color(0xFF9E003F)),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: isPink ? const Color(0xFF9E003F) : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (color == Colors.white)
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
          border: color == Colors.white
              ? Border.all(color: Colors.grey.shade200)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, {double radius = 12}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Icon(Icons.person, size: radius * 1.5, color: Colors.white)
            : null,
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return "Date TBD";
    String startStr = "${start.month}/${start.day}";
    if (end == null ||
        (start.year == end.year &&
            start.month == end.month &&
            start.day == end.day)) {
      return startStr;
    }
    String endStr = "${end.month}/${end.day}";
    return "$startStr ~ $endStr";
  }
}
