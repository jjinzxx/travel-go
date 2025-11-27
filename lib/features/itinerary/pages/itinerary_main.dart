import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/models/itinerary_model.dart'; // Region 모델 필요
import 'itinerary_public.dart';
import 'itinerary_shared.dart';
import 'itinerary_private.dart';
import 'itinerary_create_form.dart';

class ItineraryMain extends StatefulWidget {
  const ItineraryMain({super.key});

  @override
  State<ItineraryMain> createState() => _ItineraryMainState();
}

class _ItineraryMainState extends State<ItineraryMain> {
  // 필터 상태 변수
  int? _selectedRegionId;
  String? _selectedTheme;

  // 필터 UI용 데이터
  List<Region> _regions = [];
  final List<String> _themes = [
    'Food', 'Culture', 'Shopping', 'Nature', 'History', 'K-Pop', 'Adventure'
  ];

  @override
  void initState() {
    super.initState();
    _fetchRegions(); // 지역 목록 미리 가져오기
  }

  // 지역 목록 가져오기
  Future<void> _fetchRegions() async {
    try {
      final response = await Supabase.instance.client.from('Region').select().order('region_id');
      final data = response as List<dynamic>;
      setState(() {
        _regions = data.map((json) => Region.fromJson(json)).toList();
      });
    } catch (e) {
      print("Region fetch error: $e");
    }
  }

  // 필터 모달 보여주기
  void _showFilterModal() {
    // 임시 변수 (적용 버튼 누르기 전까지는 메인 상태를 바꾸지 않음)
    int? tempRegionId = _selectedRegionId;
    String? tempTheme = _selectedTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // 높이 조절 가능하게
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(20),
                height: 550,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Filters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. Region
                    const Text("Region", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip(
                          label: "All",
                          isSelected: tempRegionId == null,
                          onSelected: (selected) => setModalState(() => tempRegionId = null),
                        ),
                        ..._regions.map((region) => _buildFilterChip(
                          label: region.nameEn,
                          isSelected: tempRegionId == region.id,
                          onSelected: (selected) => setModalState(() => tempRegionId = selected ? region.id : null),
                        )),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2. Theme
                    const Text("Tags", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: "All",
                          isSelected: tempTheme == null,
                          onSelected: (selected) => setModalState(() => tempTheme = null),
                        ),
                        ..._themes.map((theme) => _buildFilterChip(
                          label: theme,
                          isSelected: tempTheme == theme,
                          onSelected: (selected) => setModalState(() => tempTheme = selected ? theme : null),
                        )),
                      ],
                    ),
                    const Spacer(),

                    // 적용 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E003F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          // 여기서 부모의 상태를 업데이트! -> 자식들이 다시 빌드됨
                          setState(() {
                            _selectedRegionId = tempRegionId;
                            _selectedTheme = tempTheme;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildFilterChip({required String label, required bool isSelected, required Function(bool) onSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF9E003F),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text('Itineraries', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 24)),
          ),
          actions: [
            // 필터 아이콘 (활성화되면 색상 변경)
            IconButton(
              icon: Icon(
                  Icons.filter_list_alt,
                  color: (_selectedRegionId != null || _selectedTheme != null) ? const Color(0xFF9E003F) : Colors.grey
              ),
              onPressed: _showFilterModal, // 모달 연결
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ItineraryCreateForm()));
                },
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text("Create", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E003F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60.0),
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25.0)),
              child: TabBar(
                indicator: BoxDecoration(borderRadius: BorderRadius.circular(25.0), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF9E003F),
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  _buildTabItem(Icons.language, "Public"),
                  _buildTabItem(Icons.people_outline, "Shared"),
                  _buildTabItem(Icons.lock_outline, "Private"),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Public 탭
            ItineraryPublic(
                filterRegionId: _selectedRegionId,
                filterTheme: _selectedTheme
            ),

            // 2. Shared 탭
            ItineraryShared(
                filterRegionId: _selectedRegionId,
                filterTheme: _selectedTheme
            ),

            // 3. Private 탭
            ItineraryPrivate(
                filterRegionId: _selectedRegionId,
                filterTheme: _selectedTheme
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label) {
    return Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)]));
  }
}