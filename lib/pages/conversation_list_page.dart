// lib/pages/conversation_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/conversation_list_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../design_system/colors.dart';
import '../design_system/typography.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({super.key});

  @override
  ConsumerState<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ConversationWithLastMessage> _allConversations = [];
  List<ConversationWithLastMessage> _filteredConversations = [];
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedConversations = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      _filterConversations();
    });
  }

  void _filterConversations() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = List.from(_allConversations);
    } else {
      _filteredConversations = _allConversations.where((conv) {
        final title = conv.conversation.title.toLowerCase();
        final summary = conv.conversation.summary?.toLowerCase() ?? '';
        final lastMessage = conv.lastMessage?.content.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return title.contains(query) ||
            summary.contains(query) ||
            lastMessage.contains(query);
      }).toList();
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedConversations.clear();
      }
    });
  }

  void _toggleConversationSelection(String conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  Future<void> _deleteSelectedConversations() async {
    if (_selectedConversations.isEmpty) return;

    final confirmed = await _showDeleteConfirmDialog(
      title: '선택한 대화 삭제',
      content: '선택한 ${_selectedConversations.length}개의 대화를 삭제하시겠습니까?',
    );

    if (confirmed == true) {
      try {
        final service = ref.read(conversationListServiceProvider);
        await service.deleteMultipleConversations(_selectedConversations.toList());

        setState(() {
          _isSelectionMode = false;
          _selectedConversations.clear();
        });

        _showSnackBar('선택한 대화가 삭제되었습니다.');
      } catch (e) {
        _showSnackBar('대화 삭제 중 오류가 발생했습니다: $e');
      }
    }
  }

  Future<void> _deleteAllConversations() async {
    final confirmed = await _showDeleteConfirmDialog(
      title: '모든 대화 삭제',
      content: '모든 대화를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
    );

    if (confirmed == true) {
      try {
        final service = ref.read(conversationListServiceProvider);
        await service.deleteAllConversations();
        _showSnackBar('모든 대화가 삭제되었습니다.');
      } catch (e) {
        _showSnackBar('대화 삭제 중 오류가 발생했습니다: $e');
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(userConversationsWithMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedConversations.length}개 선택됨')
            : Text(
          '대화 목록',
          style: AppTypography.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.main800,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _selectedConversations.isNotEmpty
                  ? _deleteSelectedConversations
                  : null,
              tooltip: '선택한 대화 삭제',
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: _toggleSelectionMode,
              tooltip: '선택 모드 종료',
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {
                // 검색 기능은 이미 항상 표시되므로 검색 창에 포커스
                FocusScope.of(context).requestFocus(FocusNode());
              },
              tooltip: '검색',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'select_mode':
                    _toggleSelectionMode();
                    break;
                  case 'delete_all':
                    _deleteAllConversations();
                    break;
                  case 'sensor_monitor':
                    Navigator.pushNamed(context, '/sensor_monitor');
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'select_mode',
                  child: ListTile(
                    leading: Icon(Icons.checklist),
                    title: Text('선택 모드'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep, color: Colors.red),
                    title: Text('모든 대화 삭제', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'sensor_monitor',
                  child: ListTile(
                    leading: Icon(Icons.sensors),
                    title: Text('센서 모니터링'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 검색 영역
          if (!_isSelectionMode)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '대화 내용을 검색하세요...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade600),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.main800),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

          // 대화 목록
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                _allConversations = conversations;
                _filterConversations();

                if (_filteredConversations.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildConversationList();
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.main800),
                    SizedBox(height: 16),
                    Text(
                      '대화 목록을 불러오는 중...',
                      style: AppTypography.b1.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      '대화 목록을 불러올 수 없습니다',
                      style: AppTypography.h4.copyWith(color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: AppTypography.b3.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.refresh(userConversationsWithMessagesProvider);
                      },
                      child: Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 새 대화 시작 버튼
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/sensor_monitor');
        },
        icon: Icon(Icons.sensors),
        label: Text('센서 대화'),
        backgroundColor: AppColors.main800,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearching ? Icons.search_off : Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            _isSearching ? '검색 결과가 없습니다' : '아직 대화가 없습니다',
            style: AppTypography.h4.copyWith(color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            _isSearching
                ? '다른 키워드로 검색해보세요'
                : '센서 모니터링으로 새로운 대화를 시작해보세요',
            style: AppTypography.b2.copyWith(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          if (!_isSearching) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/sensor_monitor');
              },
              icon: Icon(Icons.sensors),
              label: Text('센서 모니터링 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main800,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final conversationWithMessage = _filteredConversations[index];
        final conversation = conversationWithMessage.conversation;
        final isSelected = _selectedConversations.contains(conversation.id);

        return _buildConversationItem(conversationWithMessage, isSelected);
      },
    );
  }

  Widget _buildConversationItem(ConversationWithLastMessage conversationWithMessage, bool isSelected) {
    final conversation = conversationWithMessage.conversation;
    final lastMessage = conversationWithMessage.lastMessage;
    final unreadCount = conversationWithMessage.unreadCount;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.main800.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.main800 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (_isSelectionMode) {
              _toggleConversationSelection(conversation.id);
            } else {
              // 대화 페이지로 이동 (실제 구현된 대화 페이지로 수정 필요)
              Navigator.pushNamed(
                context,
                '/realtime_chat',
                arguments: conversation.id,
              );
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode();
              _toggleConversationSelection(conversation.id);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // 선택 체크박스 (선택 모드에서만)
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      _toggleConversationSelection(conversation.id);
                    },
                    activeColor: AppColors.main800,
                  ),
                  SizedBox(width: 8),
                ],

                // 대화 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.main800.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.chat_bubble,
                    color: AppColors.main800,
                    size: 24,
                  ),
                ),

                SizedBox(width: 12),

                // 대화 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목과 시간
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversationWithMessage.displayTitle,
                              style: AppTypography.b1.copyWith(
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            conversationWithMessage.displayTime,
                            style: AppTypography.b3.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      // 마지막 메시지 또는 요약
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage != null
                                  ? '${conversationWithMessage.lastSender}: ${lastMessage.content}'
                                  : conversation.summary ?? '새로운 대화',
                              style: AppTypography.b3.copyWith(
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 읽지 않은 메시지 수
                          if (unreadCount > 0) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: AppTypography.b3.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // 대화 정보 (메시지 수)
                      if (conversation.messageCount > 0) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.message, size: 12, color: Colors.grey.shade500),
                            SizedBox(width: 4),
                            Text(
                              '${conversation.messageCount}개 메시지',
                              style: AppTypography.b3.copyWith(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}