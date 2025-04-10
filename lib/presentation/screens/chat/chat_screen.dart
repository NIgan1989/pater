import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:intl/intl.dart';

/// Экран чата с конкретным пользователем
class ChatScreen extends StatefulWidget {
  final String chatId;
  
  const ChatScreen({
    super.key,
    required this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late User? _currentUser;
  bool _isLoading = true;
  List<ChatMessage> _messages = [];
  User? _chatPartner;
  
  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _loadChatData();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// Загружает данные чата
  Future<void> _loadChatData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Имитация загрузки данных
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Создаем тестовые данные
      _generateTestData();
      
      setState(() {
        _isLoading = false;
      });
      
      // Прокручиваем к последнему сообщению
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке чата: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Генерирует тестовые данные для чата
  void _generateTestData() {
    // Создаем тестового собеседника
    _chatPartner = User(
      id: widget.chatId,
      email: 'user${widget.chatId}@example.com',
      firstName: 'Пользователь',
      lastName: widget.chatId,
      phoneNumber: '+7777777777${widget.chatId}',
      role: UserRole.client,
    );
    
    // Создаем тестовые сообщения
    final now = DateTime.now();
    
    _messages = [
      ChatMessage(
        id: '1',
        senderId: _currentUser!.id,
        receiverId: _chatPartner!.id,
        text: 'Здравствуйте! Меня интересует ваше жилье.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
      ChatMessage(
        id: '2',
        senderId: _chatPartner!.id,
        receiverId: _currentUser!.id,
        text: 'Добрый день! Какие у вас вопросы?',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 45)),
        isRead: true,
      ),
      ChatMessage(
        id: '3',
        senderId: _currentUser!.id,
        receiverId: _chatPartner!.id,
        text: 'Хотел уточнить, есть ли парковка рядом с домом?',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 30)),
        isRead: true,
      ),
      ChatMessage(
        id: '4',
        senderId: _chatPartner!.id,
        receiverId: _currentUser!.id,
        text: 'Да, есть бесплатная парковка во дворе.',
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
        isRead: true,
      ),
      ChatMessage(
        id: '5',
        senderId: _currentUser!.id,
        receiverId: _chatPartner!.id,
        text: 'Отлично! А как насчет интернета?',
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      ChatMessage(
        id: '6',
        senderId: _chatPartner!.id,
        receiverId: _currentUser!.id,
        text: 'Высокоскоростной Wi-Fi включен в стоимость.',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 50)),
        isRead: true,
      ),
      ChatMessage(
        id: '7',
        senderId: _currentUser!.id,
        receiverId: _chatPartner!.id,
        text: 'Супер! Я бы хотел забронировать на следующие выходные.',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
    ];
  }
  
  /// Отправляет новое сообщение
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: _currentUser!.id,
          receiverId: _chatPartner!.id,
          text: text,
          timestamp: DateTime.now(),
          isRead: false,
        ),
      );
      
      _messageController.clear();
    });
    
    // Прокручиваем к последнему сообщению
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? const Text('Загрузка...')
            : Text(_chatPartner?.fullName ?? 'Чат'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Показать информацию о собеседнике
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Сообщения
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Нет сообщений',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(AppConstants.paddingM),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isCurrentUser = message.senderId == _currentUser!.id;
                            
                            // Проверяем, нужно ли показывать дату
                            final showDate = index == 0 || 
                                !_isSameDay(
                                  _messages[index].timestamp,
                                  _messages[index - 1].timestamp,
                                );
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDate)
                                  _buildDateDivider(theme, message.timestamp),
                                _buildMessageBubble(theme, message, isCurrentUser),
                              ],
                            );
                          },
                        ),
                ),
                
                // Поле ввода сообщения
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () {
                          // Прикрепить файл
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Введите сообщение...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusL),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.paddingM,
                              vertical: AppConstants.paddingS,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: theme.colorScheme.primary,
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  /// Строит разделитель с датой
  Widget _buildDateDivider(ThemeData theme, DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingM),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM),
            child: Text(
              _formatMessageDate(date),
              style: TextStyle(
                fontSize: AppConstants.fontSizeSmall,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Строит пузырек сообщения
  Widget _buildMessageBubble(ThemeData theme, ChatMessage message, bool isCurrentUser) {
    return Container(
      margin: EdgeInsets.only(
        top: AppConstants.paddingS,
        bottom: AppConstants.paddingS,
        left: isCurrentUser ? 64 : 0,
        right: isCurrentUser ? 0 : 64,
      ),
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingM),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isCurrentUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 4,
              left: AppConstants.paddingXS,
              right: AppConstants.paddingXS,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: message.isRead
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Форматирует дату сообщения
  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Сегодня';
    } else if (messageDate == yesterday) {
      return 'Вчера';
    } else {
      return DateFormat('d MMMM').format(date);
    }
  }
  
  /// Проверяет, относятся ли две даты к одному дню
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}

/// Модель сообщения в чате
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.isRead,
  });
} 