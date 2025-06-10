// lib/services/voice_service.dart
import 'dart:io';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart' as flutter_tts_alias; // Assign a prefix to flutter_tts
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import '../utils/simple_speech_recognizer.dart';
import '../utils/encoding_utils.dart';
import '../utils/voice_preferences.dart'; // 추가
import 'whisper_service.dart';
import 'openai_tts_service.dart';
import 'package:tiiun/services/remote_config_service.dart';
import 'package:tiiun/utils/error_handler.dart'; // The intended ErrorHandler class
import 'package:tiiun/utils/logger.dart';
import 'package:tiiun/services/voice_assistant_service.dart'; // Import SpeechRecognitionMode

// Custom Exceptions
class VoiceServiceException implements Exception {
  final String message;
  final dynamic underlyingException;
  VoiceServiceException(this.message, {this.underlyingException});
  @override
  String toString() => 'VoiceServiceException: $message ${underlyingException != null ? "(Caused by: $underlyingException)" : ""}';
}

// Provider for the voice service
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final remoteConfigService = ref.watch(remoteConfigServiceProvider);
  final openAIapiKey = remoteConfigService.getOpenAIApiKey();
  if (openAIapiKey.isEmpty) {
    AppLogger.warning('OPENAI_API_KEY is not set. OpenAI features will be limited.');
  }
  return VoiceService(authService, openAIapiKey);
});

class VoiceService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final flutter_tts_alias.FlutterTts _flutterTts = flutter_tts_alias.FlutterTts(); // Use prefix
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Uuid _uuid = const Uuid();
  final AuthService? _authService;
  final Connectivity _connectivity = Connectivity();
  final record_pkg.AudioRecorder _recorder = record_pkg.AudioRecorder();
  final SimpleSpeechRecognizer _speechRecognizer = SimpleSpeechRecognizer();

  // Expose WhisperService and OpenAiTtsService as public getters
  final WhisperService whisperService;
  final OpenAiTtsService openAiTtsService;
  final String _openAIapiKey;

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB

  bool _isOfflineMode = false;
  bool _isRecording = false;
  StreamSubscription? _connectivitySubscription;
  bool _flutterTtsInitialized = false;
  bool _speechRecognizerInitialized = false;

  // Stream for on-device STT transcriptions
  Stream<String> get onDeviceTranscriptionStream => _speechRecognizer.transcriptionStream;

  // Constructor
  VoiceService(this._authService, this._openAIapiKey)
      : whisperService = WhisperService(apiKey: _openAIapiKey),
        openAiTtsService = OpenAiTtsService(apiKey: _openAIapiKey) {
    AppLogger.info('VoiceService: Initializing...');
    _initConnectivityListener();
    _initFlutterTts();
    _initSpeechRecognizer();
  }

  // Private empty constructor for `VoiceService.empty()` factory
  VoiceService._empty(this._openAIapiKey)
      : _authService = null,
        whisperService = WhisperService(apiKey: _openAIapiKey),
        openAiTtsService = OpenAiTtsService(apiKey: _openAIapiKey) {
    AppLogger.debug("VoiceService initialized in empty/fallback state.");
    _initConnectivityListener();
    _initFlutterTts();
    _initSpeechRecognizer();
  }

  // Factory constructor for testing or specific fallback scenarios
  factory VoiceService.empty() {
    const String apiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
    return VoiceService._empty(apiKey);
  }

  void _initConnectivityListener() {
    _connectivity.checkConnectivity().then((results) {
      _isOfflineMode = results.contains(ConnectivityResult.none);
      AppLogger.info('VoiceService: Initial connectivity status: ${_isOfflineMode ? "Offline" : "Online"}');
    });
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _isOfflineMode = results.contains(ConnectivityResult.none);
      AppLogger.info('VoiceService: Connectivity changed: ${_isOfflineMode ? "Offline" : "Online"}');
    });
  }

  Future<void> _initSpeechRecognizer() async {
    try {
      _speechRecognizerInitialized = await _speechRecognizer.initialize();
      if (!_speechRecognizerInitialized) {
        AppLogger.warning('VoiceService: On-device Speech Recognizer initialization failed.');
      } else {
        AppLogger.info('VoiceService: On-device Speech Recognizer initialized successfully.');
      }
    } catch (e, stackTrace) {
      AppLogger.error('VoiceService: Error initializing on-device Speech Recognizer: $e', e, stackTrace);
      _speechRecognizerInitialized = false;
    }
  }

  Future<void> initializeSTT() async {
    await _initSpeechRecognizer();
  }

  Future<void> _initFlutterTts() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        await _flutterTts.setLanguage('ko-KR');
        await _flutterTts.setSpeechRate(0.5);
        await _flutterTts.setVolume(1.0);
        await _flutterTts.setPitch(1.0);
        _flutterTtsInitialized = true;
        AppLogger.info('VoiceService: FlutterTTS initialized successfully.');
        return;
      } catch (e, stackTrace) {
        retryCount++;
        AppLogger.warning('VoiceService: FlutterTTS initialization failed (Attempt $retryCount): $e', e, stackTrace);
        if (retryCount >= _maxRetries) {
          _flutterTtsInitialized = false;
          AppLogger.error('VoiceService: FlutterTTS initialization failed after multiple retries.');
          return;
        }
        await Future.delayed(_retryDelay);
      }
    }
  }

  Future<List<dynamic>> getAvailableVoices() async {
    if (!_flutterTtsInitialized) {
      AppLogger.warning('VoiceService: FlutterTTS not initialized. Cannot get voices.');
      return [];
    }
    try {
      return await _flutterTts.getVoices;
    } catch (e, stackTrace) {
      AppLogger.error('VoiceService: Error getting available voices: $e', e, stackTrace);
      return [];
    }
  }

  Future<void> speakWithFlutterTts(String text) async {
    return ErrorHandler.safeFuture(() async {
      if (!_flutterTtsInitialized) {
        AppLogger.warning('VoiceService: FlutterTTS not initialized. Attempting to speak might fail.');
        throw VoiceServiceException('FlutterTTS not initialized. Cannot speak.');
      }
      await _flutterTts.speak(text);
      AppLogger.debug('VoiceService: Speaking via FlutterTts: "$text"');
    });
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      _isPlaying = false;
      _currentPlayingUrl = null;
      AppLogger.debug('VoiceService: Stopped all audio playback.');
    } catch (e, stackTrace) {
      AppLogger.error('VoiceService: Error stopping TTS/audio: $e', e, stackTrace);
    }
  }

  Future<void> startRecording() async {
    return ErrorHandler.safeFuture(() async {
      if (_isRecording) {
        AppLogger.debug("VoiceService: Already recording.");
        return;
      }
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw AppError(type: AppErrorType.permission, message: '마이크 사용 권한이 없습니다.');
      }
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${_uuid.v4()}.m4a';
      await _recorder.start(
        record_pkg.RecordConfig(
          encoder: record_pkg.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );
      _isRecording = true;
      AppLogger.info('VoiceService: Recording started: $filePath');
    });
  }

  Future<String> stopRecording() async {
    return ErrorHandler.safeFuture(() async {
      if (!_isRecording) {
        throw AppError(type: AppErrorType.system, message: '녹음 중이 아닙니다.');
      }

      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        throw AppError(type: AppErrorType.data, message: '녹음 파일이 생성되지 않았습니다.');
      }

      AppLogger.info('VoiceService: Recording stopped: $path');
      return path;
    });
  }

  Future<void> startOnDeviceListening() async {
    return ErrorHandler.safeFuture(() async {
      if (!_speechRecognizerInitialized) {
        await _initSpeechRecognizer();
        if (!_speechRecognizerInitialized) {
          throw VoiceServiceException("On-device speech recognizer not initialized.");
        }
      }
      await _speechRecognizer.startListening();
      AppLogger.info("VoiceService: On-device STT listening started.");
    });
  }

  Future<void> stopOnDeviceListening() async {
    return ErrorHandler.safeFuture(() async {
      await _speechRecognizer.stopListening();
      AppLogger.info("VoiceService: On-device STT listening stopped.");
    });
  }

  Future<String> speechToText(String audioPath, {String language = 'ko'}) async {
    return ErrorHandler.safeFuture(() async {
      if (_isOfflineMode || _openAIapiKey.isEmpty) {
        AppLogger.info('VoiceService: Offline or OpenAI API key not set. Using on-device STT.');
        // Direct file-to-text is not typically supported by SimpleSpeechRecognizer.
        // This part needs careful consideration if `audioPath` is a recorded file.
        // For live audio, SimpleSpeechRecognizer streams it.
        // If audioPath is a file, an external library for local ASR would be needed or
        // we'd rely on a dummy response for offline mode.
        throw VoiceServiceException("On-device STT from file is not fully implemented or requires a dummy response for offline mode.");
      } else {
        AppLogger.info('VoiceService: Online. Using OpenAI Whisper STT.');
        try {
          return await whisperService.transcribeAudio(audioPath, language: language); // Use public getter
        } on AppError catch (e) {
          AppLogger.warning('VoiceService: Whisper STT failed: ${e.message}. Falling back to on-device STT.');
          throw VoiceServiceException("Whisper STT failed, try on-device.", underlyingException: e);
        } catch (e, stackTrace) {
          AppLogger.error('VoiceService: Whisper STT failed unexpectedly: $e', e, stackTrace);
          throw VoiceServiceException("Whisper STT failed, try on-device.", underlyingException: e);
        }
      }
    });
  }

  // New method to handle streaming STT based on mode
  Stream<String> streamSpeechToText({required SpeechRecognitionMode mode, int recordingDuration = 10, String language = 'ko'}) async* {
    if (mode == SpeechRecognitionMode.whisper) {
      yield* whisperService.streamRecordAndTranscribe(recordingDuration: recordingDuration, language: language);
    } else { // SpeechRecognitionMode.native
      yield* _speechRecognizer.transcriptionStream; // Direct stream from SimpleSpeechRecognizer
    }
  }


  Future<String> uploadVoiceFile(String filePath) async {
    return ErrorHandler.safeFuture(() async {
      final userId = _authService?.getCurrentUserId();
      if (userId == null) {
        throw VoiceServiceException('User not logged in. Cannot upload voice file.');
      }
      final file = File(filePath);
      if (!await file.exists()) {
        throw VoiceServiceException('File does not exist at path: $filePath');
      }
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        throw VoiceServiceException('File size exceeds limit of ${_maxFileSize / (1024 * 1024)}MB.');
      }

      final fileName = '${_uuid.v4()}${path.extension(filePath)}';
      final ref = _storage.ref().child('voice_messages/$userId/$fileName');

      int attempt = 0;
      while (attempt < _maxRetries) {
        try {
          if (_isOfflineMode) {
            AppLogger.debug("VoiceService: Offline mode: Saving voice file locally instead of uploading.");
            return _saveLocally(file, fileName);
          }
          final task = await ref.putFile(file);
          final downloadUrl = await task.ref.getDownloadURL();
          AppLogger.info("VoiceService: Voice file uploaded: $downloadUrl");
          return downloadUrl;
        } catch (e, stackTrace) {
          attempt++;
          AppLogger.error('VoiceService: Voice file upload failed (Attempt $attempt): $e', e, stackTrace);
          if (attempt >= _maxRetries) {
            if (_isOfflineMode) return _saveLocally(file, fileName);
            throw VoiceServiceException('Failed to upload voice file after multiple retries', underlyingException: e);
          }
          await Future.delayed(_retryDelay);
        }
      }
      throw VoiceServiceException('Failed to upload voice file.');
    });
  }

  Future<String> _saveLocally(File file, String fileName) async {
    try {
      final localDir = await getApplicationDocumentsDirectory();
      final localPath = '${localDir.path}/voice_uploads/$fileName';
      final localFile = File(localPath);
      await localFile.parent.create(recursive: true);
      await file.copy(localPath);
      AppLogger.info("VoiceService: Voice file saved locally: $localPath");
      return localPath;
    } catch (e, stackTrace) {
      AppLogger.error('VoiceService: Error saving voice file locally: $e', e, stackTrace);
      throw VoiceServiceException('Failed to save voice file locally', underlyingException: e);
    }
  }

  String? _currentPlayingUrl;
  bool _isPlaying = false;

  String? get currentPlayingUrl => _currentPlayingUrl;
  bool get isPlaying => _isPlaying;

  Future<void> playAudio(String url, {Function? onComplete, bool isLocalFile = false}) async {
    return ErrorHandler.safeFuture(() async {
      if (_audioPlayer.playing) {
        if (_currentPlayingUrl == url) {
          await _audioPlayer.stop();
          _isPlaying = false;
          _currentPlayingUrl = null;
          AppLogger.debug('VoiceService: Stopped playing the same audio: $url');
          return;
        }
        await _audioPlayer.stop();
      }

      _isPlaying = false;
      _currentPlayingUrl = null;

      AppLogger.debug('VoiceService: Attempting to play audio from: $url');

      String? effectiveUrl = url;
      bool isFilePathSource = isLocalFile || url.startsWith('/');

      if (_isOfflineMode && url.startsWith('http') && !isLocalFile) {
        AppLogger.debug("VoiceService: Offline mode: Attempting to play cached audio for $url");
        effectiveUrl = await _getCachedAudioPath(url, "playback_cache");
        if (effectiveUrl == null) {
          AppLogger.warning("VoiceService: Audio not available in offline mode and not cached, attempting to use TTS fallback.");
          await speakWithFlutterTts("음성 메시지를 재생할 수 없습니다. 오프라인 모드에서는 음성 캐시가 필요합니다.");
          throw VoiceServiceException('Audio not available offline and not cached.');
        }
        isFilePathSource = true;
      }

      if (isFilePathSource) {
        AppLogger.debug('VoiceService: Setting file path: $effectiveUrl');
        await _audioPlayer.setFilePath(effectiveUrl!);
      } else {
        AppLogger.debug('VoiceService: Setting URL: $effectiveUrl');
        await _audioPlayer.setUrl(effectiveUrl!);
      }

      _currentPlayingUrl = url;
      _isPlaying = true;

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _currentPlayingUrl = null;
          onComplete?.call();
          AppLogger.debug('VoiceService: Audio playback completed');
        }
      });

      await _audioPlayer.play();
      AppLogger.info('VoiceService: Started playing audio');
    });
  }

  Future<String?> _getCachedAudioPath(String url, String cacheDirName) async {
    try {
      final baseDir = await getTemporaryDirectory();
      final cacheDir = Directory('${baseDir.path}/$cacheDirName');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final fileName = url.split('/').last.split('?').first;
      final filePath = '${cacheDir.path}/$fileName';
      final file = File(filePath);
      return await file.exists() ? filePath : null;
    } catch (e, stackTrace) {
      AppLogger.error('VoiceService: Error getting cached audio path: $e', e, stackTrace);
      return null;
    }
  }

  /// Converts text to speech and returns the local file path or null if FlutterTTS is used.
  /// This method is for immediate playback, not necessarily saving to Firebase.
  Future<String?> textToSpeech(String text, {String? voiceId}) async {
    return ErrorHandler.safeFuture(() async {
      // voiceId가 지정되지 않은 경우 저장된 설정 사용
      String effectiveVoiceId = voiceId ?? await VoicePreferences.getSelectedVoiceId();

      if (_isOfflineMode || _openAIapiKey.isEmpty) {
        AppLogger.info('VoiceService: Offline or OpenAI API key not set. Using on-device TTS (FlutterTTS).');
        await speakWithFlutterTts(text); // Directly speaks, no file URL returned
        return null;
      } else {
        AppLogger.info('VoiceService: Online. Using OpenAI TTS.');
        try {
          final audioFilePath = await openAiTtsService.synthesizeSpeech(text, voice: effectiveVoiceId); // Use public getter
          // If a file is successfully synthesized, it will be saved locally temporarily.
          // This path might be played directly or uploaded if needed.
          return audioFilePath;
        } on AppError catch (e) {
          AppLogger.warning('VoiceService: OpenAI TTS failed: ${e.message}. Falling back to on-device TTS.');
          await speakWithFlutterTts(text);
          return null;
        } catch (e, stackTrace) {
          AppLogger.error('VoiceService: OpenAI TTS failed unexpectedly: $e', e, stackTrace);
          await speakWithFlutterTts(text);
          return null;
        }
      }
    });
  }

  /// Converts text to a speech file and returns its URL (Firebase or local path).
  ///
  /// [text]는 음성으로 변환할 텍스트입니다.
  /// [voiceId]는 사용할 음성 ID입니다 (선택 사항). null인 경우 저장된 설정 사용.
  ///
  /// 반환 값은 맵 형태로 다음 키를 포함합니다:
  /// - 'url': Firebase Storage URL 또는 로컬 파일 경로
  /// - 'duration': 오디오 파일 길이 (초)
  /// - 'source': 'openai', 'openai_local', 'local', or 'error' (TTS source)
  /// - 'error': Error message if any
  Future<Map<String, dynamic>> textToSpeechFile(String text, [String? voiceId]) async {
    return ErrorHandler.safeFuture(() async {
      // voiceId가 지정되지 않은 경우 저장된 설정 사용
      String effectiveVoiceId = voiceId ?? await VoicePreferences.getSelectedVoiceId();

      AppLogger.debug('VoiceService: textToSpeechFile called with text: "$text", voiceId: $effectiveVoiceId');

      if (text.isEmpty) {
        AppLogger.warning('VoiceService: Text for TTS is empty.');
        return {
          'url': '',
          'duration': 0.0,
          'source': 'error',
          'error': 'Text is empty'
        };
      }

      // Offline mode or no API key, use local FlutterTTS
      if (_isOfflineMode || _openAIapiKey.isEmpty) {
        AppLogger.info('VoiceService: Offline or OpenAI API key missing. Using local FlutterTTS to generate file.');
        final tempDir = await getTemporaryDirectory();
        final fileName = '${_uuid.v4()}.mp3';
        final filePath = '${tempDir.path}/$fileName';

        // Set FlutterTTS voice based on voiceId
        _setFlutterTtsVoice(effectiveVoiceId);

        try {
          await _flutterTts.synthesizeToFile(text, filePath);
          final estimatedDuration = text.length / 15.0; // Estimate ~15 chars/sec
          return {
            'url': filePath,
            'duration': estimatedDuration,
            'source': 'local',
            'error': null,
          };
        } catch (ttsError, stackTrace) {
          AppLogger.error('VoiceService: FlutterTTS file generation failed: $ttsError', ttsError, stackTrace);
          return {
            'url': '',
            'duration': 0.0,
            'source': 'error',
            'error': ttsError.toString(),
          };
        }
      } else {
        // Online mode, try OpenAI TTS
        AppLogger.info('VoiceService: Online. Attempting OpenAI TTS.');
        try {
          final audioFilePath = await openAiTtsService.synthesizeSpeech(text, voice: effectiveVoiceId); // Use public getter

          final file = File(audioFilePath);
          if (!await file.exists()) {
            AppLogger.warning('VoiceService: OpenAI TTS file not found after synthesis. Falling back to local TTS.');
            throw VoiceServiceException('OpenAI TTS file not found.');
          }

          String resultUrl = audioFilePath;
          String source = 'openai_local';
          final userId = _authService?.getCurrentUserId();

          // Firebase Storage 업로드 비활성화 (로컬 파일만 사용)
          // Firebase 업로드를 원하면 이 주석을 제거하세요
          /*
          if (userId != null) {
            try {
              AppLogger.debug('VoiceService: Attempting Firebase Storage upload.');
              final fileName = path.basename(audioFilePath);
              final ref = _storage.ref().child('tts_audio/$userId/$fileName');
              
              // 파일 존재 확인
              if (!await file.exists()) {
                throw VoiceServiceException('TTS file does not exist before upload: $audioFilePath');
              }
              
              // 파일 크기 확인
              final fileSize = await file.length();
              if (fileSize == 0) {
                throw VoiceServiceException('TTS file is empty: $audioFilePath');
              }
              
              AppLogger.debug('VoiceService: Uploading file: $fileName, size: ${fileSize} bytes');
              
              final uploadTask = await ref.putFile(file);
              final downloadUrl = await uploadTask.ref.getDownloadURL();

              AppLogger.info('VoiceService: Firebase upload successful: $downloadUrl');
              resultUrl = downloadUrl;
              source = 'openai';
            } catch (uploadError, stackTrace) {
              AppLogger.error('VoiceService: Firebase upload failed. Using local file instead: $uploadError', uploadError, stackTrace);
              // Continue with local file if upload fails
            }
          } else {
            AppLogger.warning('VoiceService: User not logged in, using local file instead of uploading');
          }
          */

          // 로컬 파일만 사용 (Firebase Storage 없이)
          AppLogger.info('VoiceService: Using local file only (Firebase Storage disabled)');
          // resultUrl = audioFilePath; (이미 설정됨)
          // source = 'openai_local'; (이미 설정됨)

          final estimatedDuration = text.length / 15.0; // Estimate ~15 chars/sec
          return {
            'url': resultUrl,
            'duration': estimatedDuration,
            'source': source,
            'error': null,
          };
        } catch (openaiError, stackTrace) {
          AppLogger.error('VoiceService: OpenAI TTS failed. Attempting FlutterTTS fallback: $openaiError', openaiError, stackTrace);
          // OpenAI failed, fall back to FlutterTTS
          _setFlutterTtsVoice(effectiveVoiceId); // Set voice for fallback
          final tempDir = await getTemporaryDirectory();
          final fileName = '${_uuid.v4()}.mp3';
          final filePath = '${tempDir.path}/$fileName';

          try {
            await _flutterTts.synthesizeToFile(text, filePath);
            final estimatedDuration = text.length / 15.0;
            return {
              'url': filePath,
              'duration': estimatedDuration,
              'source': 'local_fallback',
              'error': 'OpenAI failed: ${openaiError.toString()}',
            };
          } catch (fallbackError, fallbackStackTrace) {
            AppLogger.error('VoiceService: FlutterTTS fallback also failed: $fallbackError', fallbackError, fallbackStackTrace);
            return {
              'url': '',
              'duration': 0.0,
              'source': 'error',
              'error': 'OpenAI TTS failed: ${openaiError.toString()}, FlutterTTS fallback failed: ${fallbackError.toString()}'
            };
          }
        }
      }
    });
  }

  // Helper for setting FlutterTTS voice
  Future<void> _setFlutterTtsVoice(String? voiceId) async {
    try {
      if (!_flutterTtsInitialized) {
        await _initFlutterTts(); // Try to initialize if not already
        if (!_flutterTtsInitialized) {
          AppLogger.warning('VoiceService: FlutterTTS is not initialized for setting voice.');
          return;
        }
      }
      // Map app voice IDs to FlutterTTS local voice names or use a default.
      // This is a simplified mapping; actual voice names might vary by device.
      switch (voiceId) {
        case 'male_1':
          await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
          break;
        case 'child_1':
          await _flutterTts.setVoice({'name': 'ko-kr-x-ism-child-local', 'locale': 'ko-KR'});
          break;
        case 'calm_1':
          await _flutterTts.setVoice({'name': 'ko-kr-x-ism-calm-local', 'locale': 'ko-KR'});
          break;
        case 'alloy': // OpenAI default, map to a reasonable local voice
        case 'echo':
        case 'fable':
        case 'onyx':
        case 'nova':
        case 'shimmer':
          await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
          break;
        default:
          await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
      }
    } catch (e, stackTrace) {
      AppLogger.warning('VoiceService: Error setting FlutterTTS voice for $voiceId: $e', e, stackTrace);
      // Fallback to default if setting specific voice fails
      await _flutterTts.setLanguage('ko-KR');
    }
  }

  /// Immediately speaks the given text using the best available TTS.
  ///
  /// [text]는 음성으로 변환할 텍스트입니다.
  /// [voiceId]는 사용할 음성 ID입니다 (선택 사항). null인 경우 저장된 설정 사용.
  Future<void> speak(String text, {String? voiceId}) async {
    return ErrorHandler.safeFuture(() async {
      if (text.trim().isEmpty) {
        AppLogger.debug('VoiceService: Text is empty, stopping speak operation.');
        return;
      }

      // voiceId가 지정되지 않은 경우 저장된 설정 사용
      String effectiveVoiceId = voiceId ?? await VoicePreferences.getSelectedVoiceId();

      AppLogger.info('VoiceService: Starting speech for text: "$text", voiceId: $effectiveVoiceId');

      // Stop any ongoing playback before starting new speech
      await stopSpeaking();

      // Try OpenAI TTS if online and API key is available
      if (!_isOfflineMode && _openAIapiKey.isNotEmpty) {
        try {
          AppLogger.debug('VoiceService: Attempting OpenAI TTS for immediate playback.');
          final audioFilePath = await openAiTtsService.synthesizeSpeech(text, voice: effectiveVoiceId); // Use public getter

          final file = File(audioFilePath);
          if (!await file.exists()) {
            AppLogger.warning('VoiceService: OpenAI TTS file not found after synthesis. Falling back to FlutterTTS.');
            throw VoiceServiceException('OpenAI TTS file not found for immediate playback.');
          }

          _isPlaying = true;
          _currentPlayingUrl = 'tts_temp_${_uuid.v4()}'; // Use a unique temporary ID

          await _audioPlayer.setFilePath(audioFilePath);
          _audioPlayer.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _currentPlayingUrl = null;
              AppLogger.debug('VoiceService: OpenAI TTS playback completed.');
            }
          });
          await _audioPlayer.play();
          AppLogger.info('VoiceService: OpenAI TTS audio playback started.');
          return; // Successfully played via OpenAI, exit
        } catch (e, stackTrace) {
          AppLogger.warning('VoiceService: OpenAI TTS failed for immediate playback: $e. Falling back to FlutterTTS.', e, stackTrace);
          // Fall through to FlutterTTS if OpenAI fails
        }
      }

      // Fallback to FlutterTTS
      AppLogger.info('VoiceService: Using FlutterTTS for immediate playback.');
      await _setFlutterTtsVoice(effectiveVoiceId); // Set voice for FlutterTTS
      _isPlaying = true;
      _currentPlayingUrl = 'flutter_tts_${_uuid.v4()}'; // Unique ID for FlutterTTS playback

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _currentPlayingUrl = null;
        AppLogger.debug('VoiceService: FlutterTTS playback completed.');
      });

      await speakWithFlutterTts(text);
      AppLogger.info('VoiceService: FlutterTTS playback started.');
    });
  }

  void dispose() {
    AppLogger.info("VoiceService: Disposing resources.");
    _connectivitySubscription?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop(); // Stop any ongoing TTS
    _speechRecognizer.dispose(); // Dispose the SimpleSpeechRecognizer
    _isPlaying = false;
    _currentPlayingUrl = null;
  }
}