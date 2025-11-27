import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project1/core/models/itinerary_model.dart';
import 'package:project1/core/services/itinerary_service.dart';

class ItineraryModifyPage extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryModifyPage({super.key, required this.itinerary});

  @override
  State<ItineraryModifyPage> createState() => _ItineraryModifyPageState();
}

class _ItineraryModifyPageState extends State<ItineraryModifyPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ItineraryService();

  // 컨트롤러
  late TextEditingController _titleController;
  late TextEditingController _descController;

  // 상태 변수
  late String _selectedTheme;
  late String _postOption; // privacy
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  // 이미지 관련
  File? _newImageFile; // 새로 선택한 이미지 파일
  final ImagePicker _picker = ImagePicker();

  // 테마 옵션
  final List<String> _themeOptions = [
    'Food', 'Culture', 'Shopping', 'Nature', 'History', 'K-Pop', 'Adventure'
  ];

  @override
  void initState() {
    super.initState();
    // 기존 데이터로 초기값 설정 (Pre-fill)
    _titleController = TextEditingController(text: widget.itinerary.title);
    _descController = TextEditingController(text: widget.itinerary.description);

    // 테마가 목록에 없으면 기본값(Food) 사용
    _selectedTheme = _themeOptions.contains(widget.itinerary.theme)
        ? widget.itinerary.theme!
        : _themeOptions[0];

    _postOption = widget.itinerary.postOption; // public, shared, private
    _startDate = widget.itinerary.startDate;
    _endDate = widget.itinerary.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // 이미지 선택 (UI 로직)
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _newImageFile = File(image.path));
      }
    } catch (e) {
      print('이미지 선택 에러: $e');
    }
  }

  // 수정 저장 로직 (서비스 호출)
  Future<void> _updateItinerary() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. 이미지 처리 로직
      String? finalImageUrl = widget.itinerary.coverImageUrl; // 기본값: 기존 이미지 URL

      // 만약 새 이미지를 골랐다면 업로드 진행
      if (_newImageFile != null) {
        final uploadedUrl = await _service.uploadImage(_newImageFile!);
        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        }
      }

      // 2. DB 업데이트 (서비스 호출)
      await _service.updateItinerary(
        itineraryId: widget.itinerary.id,
        title: _titleController.text,
        description: _descController.text,
        theme: _selectedTheme,
        startDate: _startDate!,
        endDate: _endDate!,
        postOption: _postOption,
        coverImageUrl: finalImageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully! ✨')));
        Navigator.pop(context, true); // true 반환 (새로고침 신호)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 날짜 선택기
  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF9E003F))), child: child!);
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Edit Itinerary", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isSaving ? null : _updateItinerary,
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9E003F))),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지 선택 영역
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    image: _getCoverImageDecoration(), // 이미지 표시 로직 분리
                  ),
                  child: (_newImageFile == null && widget.itinerary.coverImageUrl == null)
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Change Cover Image", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  )
                      : null, // 이미지가 있으면 내용 숨김
                ),
              ),

              // Title
              _buildLabel("Title"),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration("Enter title"),
                validator: (v) => v!.isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 20),

              // Description
              _buildLabel("Description"),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: _inputDecoration("Enter description"),
              ),
              const SizedBox(height: 20),

              // Theme
              _buildLabel("Theme"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTheme,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9E003F)),
                    items: _themeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _selectedTheme = v!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Dates
              Row(children: [
                Expanded(child: _buildDateSelector("Start Date", _startDate, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateSelector("End Date", _endDate, false)),
              ]),
              const SizedBox(height: 20),

              // Privacy
              _buildLabel("Privacy"),
              Row(children: [
                _buildRadioOption("private", "Private", Icons.lock_outline),
                const SizedBox(width: 10),
                _buildRadioOption("shared", "Shared", Icons.people_outline),
                const SizedBox(width: 10),
                _buildRadioOption("public", "Public", Icons.language),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 이미지 표시 로직 (새 파일 > 기존 URL > 없음)
  DecorationImage? _getCoverImageDecoration() {
    if (_newImageFile != null) {
      return DecorationImage(image: FileImage(_newImageFile!), fit: BoxFit.cover);
    } else if (widget.itinerary.coverImageUrl != null) {
      return DecorationImage(image: NetworkImage(widget.itinerary.coverImageUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  // --- UI 헬퍼 함수들 ---
  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)));

  InputDecoration _inputDecoration(String hint) => InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[400]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF9E003F))), contentPadding: const EdgeInsets.all(16));

  Widget _buildDateSelector(String label, DateTime? date, bool isStart) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabel(label),
      GestureDetector(
        onTap: () => _selectDate(isStart),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text(date == null ? "Select" : "${date.year}-${date.month}-${date.day}", style: TextStyle(color: date == null ? Colors.grey : Colors.black)),
            const Spacer(),
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildRadioOption(String value, String label, IconData icon) {
    final isSelected = _postOption == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _postOption = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
            border: Border.all(color: isSelected ? const Color(0xFF9E003F) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, size: 20, color: isSelected ? const Color(0xFF9E003F) : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFF9E003F) : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ]),
        ),
      ),
    );
  }
}