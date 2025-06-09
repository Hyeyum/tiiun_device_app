import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:path_provider/path_provider.dart'; // path_provider is correct
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiiun/services/remote_config_service.dart';
import 'package:tiiun/utils/error_handler.dart'; // Import ErrorHandler
import 'package:tiiun/utils/logger.dart'; // Import AppLogger

final whisperServiceProvider = Provider<WhisperService>((ref) {
  final remoteConfigService = ref.watch(remoteConfigServiceProvider);
  final apiKey = remoteConfigService.getOpenAIApiKey();
  return WhisperService(apiKey: apiKey);
});

/// OpenAI Whisper API를 사용하는 최적화된 음성 인식 서비스
class WhisperService {
  final String _apiKey;
  final record_pkg.AudioRecorder _recorder = record_pkg.AudioRecorder();
  final Uuid _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentRecordingPath;
  Timer? _recordingTimer;
  final Connectivity _connectivity = Connectivity();

  WhisperService({required String apiKey}) : _apiKey = apiKey;

  /// Check if recording is active
  bool get isRecording => _isRecording;

  /// Start recording
  Future<void> startRecording() async {
    return ErrorHandler.safeFuture(() async {
      if (_isRecording) {
        AppLogger.debug('WhisperService: Already recording.');
        return;
      }

      if (!await _recorder.hasPermission()) {
        throw AppError(type: AppErrorType.permission, message: '마이크 사용 권한이 없습니다.');
      }

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/${_uuid.v4()}.m4a';

      final config = record_pkg.RecordConfig(
        encoder: record_pkg.AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      await _recorder.start(
        config,
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      AppLogger.info('WhisperService: Recording started: $_currentRecordingPath');

      _recordingTimer = Timer(const Duration(seconds: 30), () {
        if (_isRecording) {
          AppLogger.warning('WhisperService: Automatic recording stop (30-second limit).');
          stopRecording();
        }
      });
    });
  }

  /// Stop recording
  Future<String> stopRecording() async {
    return ErrorHandler.safeFuture(() async {
      if (!_isRecording) {
        throw AppError(type: AppErrorType.system, message: '녹음 중이 아닙니다.');
      }

      _recordingTimer?.cancel();
      _recordingTimer = null;

      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        throw AppError(type: AppErrorType.data, message: '녹음 파일이 생성되지 않았습니다.');
      }

      AppLogger.info('WhisperService: Recording completed: $path');
      return path;
    });
  }

  /// Check internet connection
  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Transcribe audio using Whisper API
  Future<String> transcribeAudio(String audioFilePath, {String language = 'ko'}) async {
    return ErrorHandler.safeApiCall(() async { // Use safeApiCall for network operations
      if (!await _checkInternetConnection()) {
        throw AppError(type: AppErrorType.network, message: '인터넷 연결이 필요합니다.');
      }

      if (_apiKey.isEmpty) {
        throw AppError(type: AppErrorType.authentication, message: 'OpenAI API 키가 설정되지 않았습니다. Whisper STT를 사용할 수 없습니다.');
      }

      final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final file = File(audioFilePath);

      if (!await file.exists()) {
        throw AppError(type: AppErrorType.data, message: '오디오 파일을 찾을 수 없습니다: $audioFilePath');
      }

      final fileSize = await file.length();
      AppLogger.debug('WhisperService: Audio file size: ${fileSize ~/ 1024} KB');

      if (fileSize > 24 * 1024 * 1024) { // Max 25MB for Whisper API
        throw AppError(type: AppErrorType.invalidInput, message: '오디오 파일이 너무 큽니다. 최대 크기는 24MB입니다.');
      }

      final request = http.MultipartRequest('POST', url);

      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
      });

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFilePath,
        filename: 'audio.m4a',
      ));

      request.fields['model'] = 'whisper-1';
      request.fields['language'] = language;
      request.fields['response_format'] = 'json';

      AppLogger.debug('WhisperService: Sending Whisper API request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Whisper API 요청 시간 초과');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final transcription = jsonResponse['text'] as String;
        AppLogger.info('WhisperService: Transcription result: $transcription');
        return transcription;
      } else {
        AppLogger.error('WhisperService: API error (${response.statusCode}): ${response.body}');
        throw AppError(
          type: AppErrorType.server,
          code: response.statusCode.toString(),
          message: 'Whisper API 오류가 발생했습니다.',
          details: response.body,
        );
      }
    });
  }

  /// Records and transcribes audio in one go
  Future<String> recordAndTranscribe({int maxDurationSeconds = 10, String language = 'ko'}) async {
    return ErrorHandler.safeFuture(() async {
      await startRecording();
      await Future.delayed(Duration(seconds: maxDurationSeconds));
      final audioPath = await stopRecording();
      return transcribeAudio(audioPath, language: language);
    });
  }

  /// Provides a stream of speech recognition results
  Stream<String> streamRecordAndTranscribe({int recordingDuration = 10, String language = 'ko'}) async* {
    yield '[interim]음성을 녹음하는 중입니다...';

    try {
      if (!await _checkInternetConnection()) {
        yield '[error]인터넷 연결이 필요합니다. 연결 상태를 확인해주세요.';
        yield '[listening_stopped]';
        return;
      }

      if (_apiKey.isEmpty) {
        yield '[error]OpenAI API 키가 설정되지 않아 음성 인식을 사용할 수 없습니다.';
        yield '[listening_stopped]';
        return;
      }

      await startRecording();
      await Future.delayed(Duration(seconds: recordingDuration));
      final audioPath = await stopRecording();

      yield '[interim]음성을 텍스트로 변환 중입니다...';

      try {
        final result = await transcribeAudio(audioPath, language: language);
        if (result.isNotEmpty) {
          yield result;
        } else {
          yield '[error]인식된 텍스트가 없습니다. 다시 말씀해주세요.';
        }
      } catch (e) {
        yield '[error]음성 변환 중 오류가 발생했습니다: ${e.toString()}';
      }
    } catch (e) {
      yield '[error]음성 인식 중 오류가 발생했습니다: ${e.toString()}';
    } finally {
      if (_isRecording) {
        try {
          await stopRecording();
        } catch (e) {
          AppLogger.error('WhisperService: Error stopping recording during cleanup: $e');
        }
      }

      try {
        if (_currentRecordingPath != null) {
          final recordingFile = File(_currentRecordingPath!);
          if (await recordingFile.exists()) {
            await recordingFile.delete();
            AppLogger.debug('WhisperService: Temporary recording file deleted: $_currentRecordingPath');
          }
        }
      } catch (e) {
        AppLogger.error('WhisperService: Error cleaning up temporary file: $e');
      }

      yield '[listening_stopped]';
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    AppLogger.info('WhisperService: Disposing resources.');
    _recordingTimer?.cancel();
    if (_isRecording) {
      try {
        await _recorder.stop();
        _isRecording = false;
      } catch (e) {
        AppLogger.error('WhisperService: Error stopping recorder during dispose: $e');
      }
    }
    try {
      if (_currentRecordingPath != null) {
        final recordingFile = File(_currentRecordingPath!);
        if (await recordingFile.exists()) {
          await recordingFile.delete();
        }
      }
    } catch (e) {
      AppLogger.error('WhisperService: Error deleting temporary file during dispose: $e');
    }
  }
}