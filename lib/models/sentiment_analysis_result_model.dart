// lib/models/sentiment_analysis_result_model.dart
import 'package:cloud_firestore/cloud_firestore.dart'; //

class SentimentAnalysisResult {
  final String id; //
  final String userId; //
  final String? conversationId; //
  final DateTime analyzedAt; //
  final String confidence; // FireStore 스키마에 맞춰 문자열로 수정
  final String emotionType; //
  final String sentimentalLabel; // sentimental_label (스키마 반영)

  SentimentAnalysisResult({
    required this.id,
    required this.userId,
    this.conversationId,
    required this.analyzedAt,
    required this.confidence,
    required this.emotionType,
    required this.sentimentalLabel,
  });

  factory SentimentAnalysisResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; //
    return SentimentAnalysisResult(
      id: doc.id, //
      userId: data['user_id'] ?? '', //
      conversationId: data['conversation_id'], //
      analyzedAt: (data['analyzed_at'] as Timestamp).toDate(), //
      confidence: data['confidence'] ?? '', // 문자열로 수정
      emotionType: data['emotion_type'] ?? '', //
      sentimentalLabel: data['sentimental_label'] ?? '', //
    );
  }

  // Map<String, dynamic>에서 SentimentAnalysisResult 객체를 생성하는 팩토리 생성자 (fromMap과 동일하게 사용 가능)
  factory SentimentAnalysisResult.fromMap(Map<String, dynamic> map) {
    return SentimentAnalysisResult(
      id: map['id'] ?? '', // Map에서 ID를 가져올 수 있도록 id 필드 추가. Firestore 문맥에 따라 다를 수 있음.
      userId: map['user_id'] ?? '', // user_id 필드 추가
      conversationId: map['conversation_id'], // conversation_id 필드 추가
      analyzedAt: map['analyzed_at'] is Timestamp // analyzed_at 필드 추가
          ? (map['analyzed_at'] as Timestamp).toDate()
          : (map['analyzed_at'] != null ? DateTime.parse(map['analyzed_at'].toDate().toString()) : DateTime.now()), // 수정: toDate()가 아닐 경우 string parse
      confidence: map['confidence'] ?? '',
      emotionType: map['emotion_type'] ?? '',
      sentimentalLabel: map['sentimental_label'] ?? '',
    );
  }

  // Map<String, dynamic>에서 SentimentAnalysisResult 객체를 생성하는 팩토리 생성자 (JSON 디코딩 시 주로 사용)
  factory SentimentAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SentimentAnalysisResult(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      conversationId: json['conversation_id'],
      analyzedAt: json['analyzed_at'] is Timestamp
          ? (json['analyzed_at'] as Timestamp).toDate()
          : (json['analyzed_at'] != null ? DateTime.parse(json['analyzed_at'].toString()) : DateTime.now()),
      confidence: json['confidence'] ?? '',
      emotionType: json['emotion_type'] ?? '',
      sentimentalLabel: json['sentimental_label'] ?? '',
    );
  }


  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId, //
      'conversation_id': conversationId, //
      'analyzed_at': Timestamp.fromDate(analyzedAt), //
      'confidence': confidence, //
      'emotion_type': emotionType, //
      'sentimental_label': sentimentalLabel, //
    };
  }

  // toJson 메서드 추가
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'conversation_id': conversationId,
      'analyzed_at': analyzedAt.toIso8601String(), // ISO 8601 문자열로 변환
      'confidence': confidence,
      'emotion_type': emotionType,
      'sentimental_label': sentimentalLabel,
    };
  }

  SentimentAnalysisResult copyWith({
    String? id,
    String? userId,
    String? conversationId,
    DateTime? analyzedAt,
    String? confidence,
    String? emotionType,
    String? sentimentalLabel,
  }) {
    return SentimentAnalysisResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      conversationId: conversationId ?? this.conversationId,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      confidence: confidence ?? this.confidence,
      emotionType: emotionType ?? this.emotionType,
      sentimentalLabel: sentimentalLabel ?? this.sentimentalLabel,
    );
  }
}