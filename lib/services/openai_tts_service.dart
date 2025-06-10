// lib/services/openai_tts_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiiun/services/remote_config_service.dart';
import 'package:tiiun/utils/error_handler.dart'; // Import ErrorHandler
import 'package:tiiun/utils/logger.dart'; // Import AppLogger

// Custom Exceptions (can be moved to a shared file like AppError)
class OpenAiTtsApiException extends AppError { // Inherit from AppError
  OpenAiTtsApiException(String message, {int? statusCode, dynamic originalException})
      : super(
    type: AppErrorType.server, // Or other appropriate type
    message: message,
    code: statusCode?.toString() ?? 'openai_tts_api_error', // statusCode is mapped to 'code'
    originalException: originalException,
  );

  // Add the statusCode getter to expose the integer status code
  @override // Marking as override if AppError also defines 'statusCode' (though it doesn't by default)
  int? get statusCode {
    // Attempt to parse the 'code' string back to an int
    // This assumes that `code` was set with an int status code string.
    return int.tryParse(code);
  }
}

class NetworkException extends AppError { // Inherit from AppError
  NetworkException(String message, {dynamic originalException})
      : super(
    type: AppErrorType.network,
    message: message,
    code: 'network_error',
    originalException: originalException,
  );
}

final openAiTtsServiceProvider = Provider<OpenAiTtsService>((ref) {
  final remoteConfigService = ref.watch(remoteConfigServiceProvider);
  final apiKey = remoteConfigService.getOpenAIApiKey();
  return OpenAiTtsService(apiKey: apiKey);
});


class OpenAiTtsService {
  final String _apiKey;
  final Uuid _uuid = const Uuid();
  final Connectivity _connectivity = Connectivity();

  // API Endpoint
  final String _ttsApiUrl = 'https://api.openai.com/v1/audio/speech';

  // Retry constants
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  OpenAiTtsService({required String apiKey}) : _apiKey = apiKey;

  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Generates audio from text using OpenAI TTS API and returns the local file path.
  ///
  /// Throws [NetworkException] if there's no internet connection.
  /// Throws [OpenAiTtsApiException] for API errors or other issues during TTS generation.
  Future<String> generateSpeech({
    required String text,
    String model = 'tts-1', // 'tts-1' or 'tts-1-hd'
    String voice = 'alloy', // 'alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'
    String responseFormat = 'mp3', // 'mp3', 'opus', 'aac', 'flac'
    double speed = 1.0, // 0.25 to 4.0
  }) async {
    return ErrorHandler.safeApiCall(() async { // Use safeApiCall for network operations
      if (!await _checkInternetConnection()) {
        throw NetworkException('인터넷 연결이 필요합니다. OpenAI TTS는 인터넷 연결이 필요합니다.');
      }

      if (_apiKey.isEmpty) {
        throw OpenAiTtsApiException('OpenAI API 키가 설정되지 않았습니다. Firebase Remote Config에서 설정해주세요.');
      }

      int attempt = 0;
      while (attempt < _maxRetries) {
        try {
          final headers = {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          };

          final body = jsonEncode({
            'model': model,
            'input': text,
            'voice': voice,
            'response_format': responseFormat,
            'speed': speed,
          });

          AppLogger.debug('OpenAiTtsService: Sending OpenAI TTS request (Attempt ${attempt + 1}): $body');
          final response = await http.post(
            Uri.parse(_ttsApiUrl),
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 30), onTimeout: () {
            throw TimeoutException('OpenAI TTS API 요청 시간이 초과되었습니다.');
          });

          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/${_uuid.v4()}.$responseFormat';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            AppLogger.info('OpenAiTtsService: OpenAI TTS audio saved to: $filePath');
            return filePath;
          } else {
            String errorMessage = 'Failed to generate speech.';
            try {
              final errorBody = jsonDecode(response.body);
              if (errorBody['error'] != null && errorBody['error']['message'] != null) {
                errorMessage = errorBody['error']['message'];
              }
            } catch (e, stackTrace) {
              AppLogger.error('OpenAiTtsService: Could not parse error response body: ${response.body}', e, stackTrace);
            }
            AppLogger.error('OpenAiTtsService: OpenAI TTS API Error (${response.statusCode}): $errorMessage');

            if (response.statusCode == 401) {
              throw OpenAiTtsApiException('권한 없음. OpenAI API 키를 확인해주세요.', statusCode: response.statusCode);
            }
            // Retry for rate limits or server errors
            if (response.statusCode == 429 || response.statusCode >= 500) {
              throw OpenAiTtsApiException(errorMessage, statusCode: response.statusCode);
            }
            throw OpenAiTtsApiException(errorMessage, statusCode: response.statusCode);
          }
        } on SocketException catch (e, stackTrace) {
          AppLogger.error('OpenAiTtsService: Network error during OpenAI TTS request (Attempt ${attempt + 1}): $e', e, stackTrace);
          if (attempt + 1 >= _maxRetries) {
            throw NetworkException('네트워크 오류: ${e.message}', originalException: e);
          }
        } on TimeoutException catch (e, stackTrace) {
          AppLogger.error('OpenAiTtsService: Timeout error during OpenAI TTS request (Attempt ${attempt + 1}): $e', e, stackTrace);
          if (attempt + 1 >= _maxRetries) {
            throw NetworkException('요청 시간이 초과되었습니다: ${e.message}', originalException: e);
          }
        } on OpenAiTtsApiException catch (e, stackTrace) {
          // Use e.statusCode directly now that the getter is defined
          if (e.statusCode == 429 || (e.statusCode != null && e.statusCode! >= 500)) {
            AppLogger.warning('OpenAiTtsService: OpenAI TTS API error (Attempt ${attempt + 1}), retrying: ${e.message}', e, stackTrace);
            if (attempt + 1 >= _maxRetries) rethrow; // Rethrow after max retries
          } else {
            rethrow; // Rethrow other API errors immediately
          }
        } catch (e, stackTrace) {
          AppLogger.error('OpenAiTtsService: Unexpected error during OpenAI TTS request (Attempt ${attempt + 1}): $e', e, stackTrace);
          if (attempt + 1 >= _maxRetries) {
            throw OpenAiTtsApiException('예상치 못한 오류가 발생했습니다: ${e.toString()}', originalException: e);
          }
        }
        attempt++;
        await Future.delayed(_retryDelay);
      }
      throw OpenAiTtsApiException('여러 번의 재시도 후 음성 생성에 실패했습니다.');
    });
  }

  /// Alias for generateSpeech with simpler interface.
  /// Synthesizes text to speech and returns the local file path.
  ///
  /// [text] is the text to convert to speech.
  /// [voice] is the voice ID or style to use.
  Future<String> synthesizeSpeech(String text, {String? voice}) async {
    // Convert app-specific voice IDs to OpenAI TTS API voice names
    String openAiVoice = 'alloy'; // Default OpenAI voice

    if (voice != null) {
      switch (voice) {
        case 'male_1':
          openAiVoice = 'onyx';
          break;
        case 'child_1':
          openAiVoice = 'nova';
          break;
        case 'calm_1':
          openAiVoice = 'shimmer';
          break;
        case 'alloy': // These are already OpenAI voices
        case 'echo':
        case 'fable':
        case 'onyx':
        case 'nova':
        case 'shimmer':
          openAiVoice = voice; // Use the provided OpenAI voice directly
          break;
        default:
          openAiVoice = 'alloy'; // Fallback for unknown voice IDs
          break;
      }
    }
    AppLogger.debug('OpenAiTtsService: Synthesizing speech with OpenAI voice: $openAiVoice');
    return generateSpeech(
      text: text,
      voice: openAiVoice,
      speed: 1.0,
    );
  }

  // Optional: Method to clean up old TTS files if needed, though OS usually handles temp files.
  Future<void> cleanupOldFiles(String directoryPath, {Duration maxAge = const Duration(days: 1)}) async {
    try {
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        final now = DateTime.now();
        await for (final entity in directory.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > maxAge) {
              await entity.delete();
              AppLogger.debug('OpenAiTtsService: Deleted old TTS file: ${entity.path}');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('OpenAiTtsService: Error cleaning up old TTS files: $e', e, stackTrace);
    }
  }
}