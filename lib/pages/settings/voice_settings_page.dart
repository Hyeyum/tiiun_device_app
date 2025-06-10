import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';
import 'package:tiiun/services/voice_service.dart';

class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage> {
  String _selectedVoice = 'alloy'; // 기본값
  bool _isPlaying = false;

  // 사용 가능한 목소리들
  final Map<String, VoiceInfo> _voices = {
    'plant': VoiceInfo(
      id: 'plant',
      name: '🌱 이파리',
      description: '자연의 지혜로 위로하는 식물 AI',
      type: VoiceType.special,
    ),
    'alloy': VoiceInfo(
      id: 'alloy',
      name: '앨로이',
      description: '중성적이고 부드러운 목소리',
      type: VoiceType.openai,
    ),
    'echo': VoiceInfo(
      id: 'echo',
      name: '에코',
      description: '남성적이고 깊은 목소리',
      type: VoiceType.openai,
    ),
    'fable': VoiceInfo(
      id: 'fable',
      name: '페이블',
      description: '여성적이고 따뜻한 목소리',
      type: VoiceType.openai,
    ),
    'onyx': VoiceInfo(
      id: 'onyx',
      name: '오닉스',
      description: '남성적이고 힘 있는 목소리',
      type: VoiceType.openai,
    ),
    'nova': VoiceInfo(
      id: 'nova',
      name: '노바',
      description: '젊고 활기찬 목소리',
      type: VoiceType.openai,
    ),
    'shimmer': VoiceInfo(
      id: 'shimmer',
      name: '시머',
      description: '부드럽고 차분한 목소리',
      type: VoiceType.openai,
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadSelectedVoice();
  }

  Future<void> _loadSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedVoice = prefs.getString('selected_voice') ?? 'alloy';
    });
  }

  Future<void> _saveSelectedVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_voice', voiceId);
    setState(() {
      _selectedVoice = voiceId;
    });
  }

  Future<void> _testVoice(String voiceId) async {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    try {
      final voiceService = ref.read(voiceServiceProvider);

      // 식물 페르소나는 특별한 테스트 메시지
      String testMessage;
      if (voiceId == 'plant') {
        testMessage = '🌱 안녕, 나는 이파리야. 너의 마음을 나누고 싶어.';
      } else {
        testMessage = '안녕하세요! 이 목소리가 마음에 드시나요?';
      }

      await voiceService.speak(testMessage, voiceId: voiceId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('목소리 테스트에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '목소리 설정',
          style: AppTypography.s2.withColor(Colors.white),
        ),
        backgroundColor: AppColors.main800,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              color: AppColors.main100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '음성 어시스턴트 목소리',
                    style: AppTypography.s2.withColor(AppColors.main800),
                  ),
                  Text(
                    '원하는 목소리를 선택하고 테스트해보세요.',
                    style: AppTypography.c2.withColor(AppColors.grey600),
                  ),
                ],
              ),
            ),

            // 목소리 목록
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(20),
                itemCount: _voices.length,
                itemBuilder: (context, index) {
                  final voice = _voices.values.elementAt(index);
                  final isSelected = _selectedVoice == voice.id;

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppColors.main500 : AppColors.grey300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? AppColors.main100 : Colors.white,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (voice.type == VoiceType.special ? Colors.green.shade500 : AppColors.main500)
                              : (voice.type == VoiceType.special ? Colors.green.shade200 : AppColors.grey200),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          voice.type == VoiceType.special
                              ? Icons.eco // 식물 아이콘
                              : Icons.record_voice_over,
                          color: isSelected
                              ? Colors.white
                              : (voice.type == VoiceType.special ? Colors.green.shade700 : AppColors.grey600),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        voice.name,
                        style: AppTypography.label.withColor(
                          isSelected ? AppColors.main800 : AppColors.grey900,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            voice.description,
                            style: AppTypography.b2.withColor(AppColors.grey600),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: voice.type == VoiceType.openai
                                  ? AppColors.main100
                                  : voice.type == VoiceType.special
                                  ? Colors.green.shade100
                                  : AppColors.grey100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              voice.type == VoiceType.openai
                                  ? 'OpenAI'
                                  : voice.type == VoiceType.special
                                  ? '🌱 특별 AI'
                                  : 'Device',
                              style: AppTypography.b3.withColor(
                                voice.type == VoiceType.openai
                                    ? AppColors.main700
                                    : voice.type == VoiceType.special
                                    ? Colors.green.shade700
                                    : AppColors.grey700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 테스트 버튼
                          IconButton(
                            onPressed: _isPlaying ? null : () => _testVoice(voice.id),
                            icon: _isPlaying
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.main500,
                                ),
                              ),
                            )
                                : Icon(
                              Icons.play_arrow,
                              color: AppColors.main500,
                              size: 28,
                            ),
                          ),
                          // 선택 라디오
                          Radio<String>(
                            value: voice.id,
                            groupValue: _selectedVoice,
                            onChanged: (value) {
                              if (value != null) {
                                _saveSelectedVoice(value);
                              }
                            },
                            activeColor: AppColors.main500,
                          ),
                        ],
                      ),
                      onTap: () => _saveSelectedVoice(voice.id),
                    ),
                  );
                },
              ),
            ),

            // 하단 안내
            Container(
              padding: EdgeInsets.all(20),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.grey600,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'OpenAI 목소리는 인터넷 연결이 필요하며, 오프라인 시 기기 목소리가 사용됩니다.',
                        style: AppTypography.b3.withColor(AppColors.grey700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceInfo {
  final String id;
  final String name;
  final String description;
  final VoiceType type;

  VoiceInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
  });
}

enum VoiceType {
  openai,
  device,
  special, // 🌱 식물 페르소나 등 특별한 AI
}
