// lib/models/conversation_model.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 대화 모델 - 실제 Firestore 스키마에 맞게 구현
class Conversation {
  /// 고유 ID (Document ID)
  final String id;
  
  /// 사용자 ID (Firestore 필수)
  final String userId;
  
  /// 생성 시간 (Firestore 필수)
  final DateTime createdAt;
  
  /// 업데이트 시간 (Firestore 필수)  
  final DateTime updatedAt;
  
  /// 마지막 메시지 ID (Firestore 필수)
  final String? lastMessageId;
  
  /// 메시지 수 (Firestore 필수)
  final int messageCount;
  
  /// 플랜트 ID (Firestore 필수)
  final String? plantId;
  
  /// 대화 요약 (Firestore 필수)
  final String? summary;
  
  // UI 표시용 추가 필드들
  final String? lastMessageContent;
  final String? lastMessageSender;
  final String title; // UI에서 표시할 제목

  Conversation({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageId,
    required this.messageCount,
    this.plantId,
    this.summary,
    this.lastMessageContent,
    this.lastMessageSender,
    String? title,
  }) : title = title ?? _generateTitle(createdAt);

  /// 시간 기반 기본 제목 생성
  static String _generateTitle(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inDays == 0) {
      return '오늘 ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} 대화';
    } else if (diff.inDays == 1) {
      return '어제 대화';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전 대화';
    } else {
      return '${createdAt.month}월 ${createdAt.day}일 대화';
    }
  }

  /// 빈 대화 생성
  factory Conversation.empty() {
    final now = DateTime.now();
    return Conversation(
      id: '',
      userId: '',
      createdAt: now,
      updatedAt: now,
      messageCount: 0,
    );
  }

  /// Firestore 데이터에서 객체 생성
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
        throw Exception('Document data is null');
      }

      return Conversation(
        id: doc.id,
        userId: data['user_id'] ?? '',
        createdAt: data['created_at'] != null 
            ? (data['created_at'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: data['updated_at'] != null
            ? (data['updated_at'] as Timestamp).toDate()
            : DateTime.now(),
        lastMessageId: data['last_message_id'],
        messageCount: data['message_count'] ?? 0,
        plantId: data['plant_id'],
        summary: data['summary'],
      );
    } catch (e) {
      debugPrint('Error creating Conversation from Firestore: $e');
      final now = DateTime.now();
      return Conversation(
        id: doc.id,
        userId: '',
        createdAt: now,
        updatedAt: now,
        messageCount: 0,
        title: '오류가 발생한 대화',
      );
    }
  }

  /// Firestore에 저장할 데이터로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'last_message_id': lastMessageId,
      'message_count': messageCount,
      'plant_id': plantId,
      'summary': summary,
    };
  }

  /// 객체 복사본 생성
  Conversation copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessageId,
    int? messageCount,
    String? plantId,
    String? summary,
    String? lastMessageContent,
    String? lastMessageSender,
    String? title,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      messageCount: messageCount ?? this.messageCount,
      plantId: plantId ?? this.plantId,
      summary: summary ?? this.summary,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      title: title ?? this.title,
    );
  }

  /// JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_id': lastMessageId,
      'message_count': messageCount,
      'plant_id': plantId,
      'summary': summary,
      'title': title,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessageId: json['last_message_id'],
      messageCount: json['message_count'] ?? 0,
      plantId: json['plant_id'],
      summary: json['summary'],
      title: json['title'],
    );
  }

  /// 포맷된 시간 문자열
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    
    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${updatedAt.month}/${updatedAt.day}';
    }
  }

  /// 대화가 최근인지 확인 (24시간 이내)
  bool get isRecent {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    return diff.inHours < 24;
  }

  /// 대화가 활성 상태인지 확인 (1시간 이내)
  bool get isActive {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    return diff.inMinutes < 60;
  }
}
