import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project1/core/services/itinerary_service.dart'; // ✅ 서비스 import

class ItineraryCreateForm extends StatefulWidget {
  const ItineraryCreateForm({super.key});

  @override
  State<ItineraryCreateForm> createState() => _ItineraryCreateFormState();
}

class _ItineraryCreateFormState extends State<ItineraryCreateForm> {
  // 서비스 인스턴스 생성
  final _service = ItineraryService();
  final _formKey = GlobalKey<FormState>();

  // 컨트롤러
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // 상태 변수
  String _selectedTheme = 'Food'; // DB Enum과 일치시킬 것
  DateTime? _startDate;
  DateTime? _endDate;
  String _privacy = 'private';
  bool _isLoading = false;

  // 이미지 관련
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // 테마 옵션
  final List<String> _themeOptions = [
    'Food', 'Culture', 'Shopping', 'Nature', 'History', 'K-Pop', 'Adventure'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // 이미지 선택 (UI 로직이므로 여기에 유지)
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _imageFile = File(image.path));
      }
    } catch (e) {
      print('이미지 선택 에러: $e');
    }
  }

  // 💾 저장 로직 (서비스 호출로 간소화됨!)
  Future<void> _saveItinerary() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates.')));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 이미지 업로드 (이미지가 있으면 서비스 통해 업로드, 없으면 랜덤 이미지)
      String? coverUrl;
      if (_imageFile != null) {
        coverUrl = await _service.uploadImage(_imageFile!);
      } else {
        coverUrl = 'https://picsum.photos/400/200?random=${DateTime.now().millisecondsSinceEpoch}';
      }

      // 2. DB 저장 (서비스 호출)
      await _service.createItinerary(
        userId: user.id,
        title: _titleController.text,
        description: _descController.text,
        theme: _selectedTheme,
        startDate: _startDate!,
        endDate: _endDate!,
        postOption: _privacy,
        coverImageUrl: coverUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Created successfully! 🎉')));
        Navigator.pop(context, true); // 성공 신호와 함께 닫기
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 날짜 선택 함수
  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
          if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Itinerary", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveItinerary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9E003F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save", style: TextStyle(color: Colors.white)),
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
              // 📸 이미지 선택 영역
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
                    image: _imageFile != null
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Add Cover Image", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  )
                      : null,
                ),
              ),

              // Title
              _buildLabel('Title'),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('e.g., My Seoul Adventure'),
                validator: (v) => v!.isEmpty ? 'Please enter title' : null,
              ),
              const SizedBox(height: 20),

              // Description
              _buildLabel('Description'),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: _inputDecoration('Describe your itinerary...'),
              ),
              const SizedBox(height: 20),

              // Theme (Dropdown)
              _buildLabel('Theme'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _themeOptions.contains(_selectedTheme) ? _selectedTheme : _themeOptions[0],
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
                Expanded(child: _buildDateSelector('Start Date', _startDate, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateSelector('End Date', _endDate, false)),
              ]),
              const SizedBox(height: 20),

              // Privacy
              _buildLabel('Privacy'),
              Row(children: [
                _buildPrivacyOption('private', 'Private', Icons.lock_outline),
                const SizedBox(width: 12),
                _buildPrivacyOption('shared', 'Shared', Icons.people_outline),
                const SizedBox(width: 12),
                _buildPrivacyOption('public', 'Public', Icons.language),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
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
            Text(date == null ? 'Select Date' : "${date.year}-${date.month}-${date.day}", style: TextStyle(color: date == null ? Colors.grey : Colors.black)),
            const Spacer(),
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          ]),
        ),
      )
    ]);
  }

  Widget _buildPrivacyOption(String value, String label, IconData icon) {
    final isSelected = _privacy == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _privacy = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
            border: Border.all(color: isSelected ? const Color(0xFF9E003F) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: isSelected ? const Color(0xFF9E003F) : Colors.grey, size: 20),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFF9E003F) : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}