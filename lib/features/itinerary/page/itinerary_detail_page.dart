import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/features/itinerary/pages/itinerary_modify_page.dart';

class ItineraryDetailPage extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryDetailPage({super.key, required this.itinerary});

  @override
  State<ItineraryDetailPage> createState() => _ItineraryDetailPageState();
}

class _ItineraryDetailPageState extends State<ItineraryDetailPage> {
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
    _fetchLikeInfo();
    _fetchPlaces();
    _checkAuthority();
  }

  // --- [Logic Section] ---

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

    // 1. 로그인 안 했으면 수정 불가 (보기 전용)
    if (myId == null) {
      if (mounted) setState(() => _canEdit = false);
      return;
    }

    // 2. Public이면? -> "모두가 수정 가능"
    if (_itinerary.postOption == 'public') {
      if (mounted) setState(() => _canEdit = true); // 무조건 허용
      return;
    }

    // 3. 작성자(Owner)라면? -> "무조건 수정 가능"
    if (_itinerary.userId == myId) {
      if (mounted) setState(() => _canEdit = true); // 무조건 허용
      return;
    }

    // 4. Shared 또는 Private인 경우 -> "초대된 멤버만 수정 가능"
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('ItineraryMember')
          .select()
          .eq('itinerary_id', _itinerary.id)
          .eq('user_id', myId)
          .maybeSingle();

      // 멤버 데이터가 있으면 true(수정 가능), 없으면 false(보기만 가능)
      if (mounted) setState(() => _canEdit = response != null);

    } catch (e) {
      print("권한 확인 에러: $e");
      if (mounted) setState(() => _canEdit = false);
    }
  }

  // 수정 후 데이터 새로고침
  Future<void> _refetchItineraryDetail() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
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

  // 장소 가져오기
  Future<void> _fetchPlaces() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('ItineraryPlace')
          .select('*, Place(*), ItineraryDay(day_num)')
          .eq('itinerary_id', _itinerary.id)
          .order('route_id', ascending: true);

      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _allPlaces = data
              .map((json) => ItineraryItem.fromJson(json))
              .toList();
          _isPlacesLoading = false;
        });
      }
    } catch (e) {
      print('Fetch Places Error: $e');
      if (mounted) setState(() => _isPlacesLoading = false);
    }
  }

  // 장소 추가
  Future<void> _addPlaceToItinerary(Place place, int targetDayNum) async {
    final supabase = Supabase.instance.client;
    try {
      final dayResponse = await supabase
          .from('ItineraryDay')
          .select()
          .eq('itinerary_id', _itinerary.id)
          .eq('day_num', targetDayNum)
          .maybeSingle();

      int targetDayId;
      if (dayResponse != null) {
        targetDayId = dayResponse['day_id'];
      } else {
        final newDay = await supabase
            .from('ItineraryDay')
            .insert({'itinerary_id': _itinerary.id, 'day_num': targetDayNum})
            .select()
            .single();
        targetDayId = newDay['day_id'];
      }

      await supabase.from('ItineraryPlace').insert({
        'itinerary_id': _itinerary.id,
        'place_id': place.id,
        'day_id': targetDayId,
      });

      await _fetchPlaces();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'${place.name}' added to Day $targetDayNum!"),
          ),
        );
      }
    } catch (e) {
      print("Add Place Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // 장소 삭제
  Future<void> _deletePlace(int routeId) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('ItineraryPlace').delete().eq('route_id', routeId);
      setState(() {
        _allPlaces.removeWhere((item) => item.routeId == routeId);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Place removed.")));
      }
    } catch (e) {
      print("Delete Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
      }
    }
  }

  // 좋아요 정보 로드
  Future<void> _fetchLikeInfo() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    try {
      final countResponse = await supabase
          .from('ItineraryLikes')
          .count(CountOption.exact)
          .eq('itinerary_id', _itinerary.id);

      bool myLike = false;
      if (userId != null) {
        final myLikeResponse = await supabase
            .from('ItineraryLikes')
            .select()
            .eq('itinerary_id', _itinerary.id)
            .eq('user_id', userId)
            .maybeSingle();
        if (myLikeResponse != null) myLike = true;
      }
      if (mounted) {
        setState(() {
          _likeCount = countResponse;
          _isLiked = myLike;
        });
      }
    } catch (e) {
      print('Fetch Like Error: $e');
    }
  }

  // 좋아요 토글
  Future<void> _toggleLike() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You need to log in.')));
      return;
    }
    if (_isLikeLoading) return;

    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await supabase.from('ItineraryLikes').insert({
          'user_id': userId,
          'itinerary_id': _itinerary.id,
        });
      } else {
        await supabase.from('ItineraryLikes').delete().match({
          'user_id': userId,
          'itinerary_id': _itinerary.id,
        });
      }
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      print('Toggle Like Error: $e');
    } finally {
      setState(() => _isLikeLoading = false);
    }
  }

  // 장소 검색
  Future<void> _searchPlaces(
    String query,
    Function(List<Place>) onResult,
  ) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('Place')
          .select()
          .or('name_kr.ilike.%$query%, name_en.ilike.%$query%')
          .limit(10);
      final data = response as List<dynamic>;
      onResult(data.map((json) => Place.fromJson(json)).toList());
    } catch (e) {
      onResult([]);
    }
  }

  // 멤버 초대
  Future<void> _inviteUser(String targetUserId, String targetNickname) async {
    final supabase = Supabase.instance.client;
    if (targetUserId == supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot invite yourself.")),
      );
      return;
    }
    try {
      await supabase.from('ItineraryMember').insert({
        'itinerary_id': _itinerary.id,
        'user_id': targetUserId,
        'role': 'editor',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$targetNickname invited successfully!")),
        );
      }
    } catch (e) {
      if (e.toString().contains('duplicate key')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User is already a member.")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Invite failed: $e")));
      }
    }
  }

  // 일정 복사 함수
  Future<void> _copyItinerary() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    // 1. 로그인 체크
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to copy this itinerary.")),
      );
      return;
    }

    // 2. 복사 진행
    try {
      // rpc: Remote Procedure Call (아까 만든 SQL 함수 실행)
      await supabase.rpc('copy_itinerary', params: {
        'source_itinerary_id': _itinerary.id, // 현재 보고 있는 여행 ID
        'new_owner_id': userId,               // 내 ID
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Copied to your Private tab!")),
        );
      }
    } catch (e) {
      print("복사 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Copy failed: $e")),
        );
      }
    }
  }

  // --- [Dialogs Section] ---

  // 장소 추가 다이얼로그
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
                          : searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                "No places found.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
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

  // 멤버 초대 다이얼로그
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
                              hintText: "Search by nickname...",
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
                            final res = await Supabase.instance.client
                                .from('Users')
                                .select()
                                .ilike(
                                  'name',
                                  '%${searchController.text}%',
                                ) // name or nickname 확인 필요
                                .limit(5);
                            setModalState(() {
                              searchResults = List<Map<String, dynamic>>.from(
                                res,
                              );
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
                          : searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                "No users found.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
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

  // --- [UI Section] ---

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
              // 수정 버튼
              if (isOwner)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    icon: const Icon(
                      Icons.edit,
                      color: Color(0xFF9e003f),
                    ),
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
              // 초대 버튼
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
              // 태그
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

          // 2. 본문 내용 (설명 및 액션 버튼)
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

          // 3. Day 1 ~ Day N 까지 반복 리스트
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
    );
  }

  // --- [Helper Widgets] ---

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
            start.day == end.day))
      return startStr;
    String endStr = "${end.month}/${end.day}";
    return "$startStr ~ $endStr";
  }
}
