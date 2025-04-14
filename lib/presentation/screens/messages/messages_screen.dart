import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/presentation/widgets/common/app_button.dart';
import 'package:pater/data/services/messaging_service.dart';

/// Экран сообщений, доступный из нижней навигации
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _authService = GetIt.instance.get<AuthService>();
  final MessagingService _messagingService = MessagingService();

  late User? _user;
  bool _isLoading = true;
  List<ChatPreview> _chats = [];
  String? _errorMessage;

  // Поиск
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Добавляем переменную для хранения последнего удаленного чата
  ChatPreview? _lastDeletedChat;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
    _loadChats();

    // Добавляем тестовые данные
    _generateTestData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Загружает чаты пользователя
  Future<void> _loadChats() async {
    if (_user == null) {
      setState(() {
        _errorMessage = 'Для доступа к сообщениям необходимо авторизоваться';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Здесь должна быть реальная загрузка чатов из сервиса
      // В данном примере используем тестовые данные

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при загрузке сообщений: $e';
        _isLoading = false;
      });
    }
  }

  /// Генерирует тестовые данные для демонстрации
  void _generateTestData() {
    final now = DateTime.now();

    _chats = [
      ChatPreview(
        id: '1',
        userId: 'user1',
        userName: 'Анна Королева',
        userAvatar: 'assets/images/avatars/woman1.jpg',
        lastMessage: 'Когда можно будет заехать?',
        timestamp: now.subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
        propertyId: 'prop1',
        propertyTitle: 'Уютная квартира в центре',
        propertyImage:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267',
        userRole: UserRole.client,
      ),
      ChatPreview(
        id: '2',
        userId: 'user2',
        userName: 'Максим Дубров',
        userAvatar: 'assets/images/avatars/man1.jpg',
        lastMessage: 'Спасибо за помощь с уборкой!',
        timestamp: now.subtract(const Duration(hours: 2)),
        unreadCount: 0,
        isOnline: false,
        propertyId: 'prop2',
        propertyTitle: 'Квартира с видом на море',
        propertyImage:
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688',
        userRole: UserRole.client,
      ),
      ChatPreview(
        id: '3',
        userId: 'user3',
        userName: 'Екатерина Иванова',
        userAvatar: 'assets/images/avatars/woman2.jpg',
        lastMessage: 'Договорились, буду ждать.',
        timestamp: now.subtract(const Duration(days: 1)),
        unreadCount: 1,
        isOnline: true,
        propertyId: 'prop1',
        propertyTitle: 'Уютная квартира в центре',
        propertyImage:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267',
        userRole: UserRole.client,
      ),
      ChatPreview(
        id: '4',
        userId: 'cleaner1',
        userName: 'Лиза Маркова',
        userAvatar: 'assets/images/avatars/woman3.jpg',
        lastMessage: 'Как доберетесь, напишите.',
        timestamp: now.subtract(const Duration(days: 2)),
        unreadCount: 0,
        isOnline: false,
        propertyId: 'prop2',
        propertyTitle: 'Квартира с видом на море',
        propertyImage:
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688',
        userRole: UserRole.cleaner,
      ),
      ChatPreview(
        id: '5',
        userId: 'support',
        userName: 'Поддержка Pater',
        userAvatar: null,
        lastMessage: 'Добрый день! Чем можем помочь?',
        timestamp: now.subtract(const Duration(days: 5)),
        unreadCount: 0,
        isOnline: true,
        propertyId: null,
        propertyTitle: null,
        propertyImage: null,
        userRole: UserRole.support,
      ),
    ];
  }

  /// Фильтрует чаты по поисковому запросу
  List<ChatPreview> _getFilteredChats() {
    if (_searchController.text.isEmpty) {
      return _chats;
    }

    final query = _searchController.text.toLowerCase();
    return _chats.where((chat) {
      return chat.userName.toLowerCase().contains(query) ||
          (chat.propertyTitle?.toLowerCase().contains(query) ?? false) ||
          chat.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          context.goNamed('home');
        }
        return;
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title:
              _isSearching
                  ? TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по сообщениям',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    style: theme.textTheme.titleMedium,
                    onChanged: (value) {
                      setState(() {});
                    },
                    autofocus: true,
                  )
                  : const Text('Сообщения'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorState(theme)
                : _buildContent(theme),
      ),
    );
  }

  /// Строит отображение ошибки
  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: AppConstants.paddingL),
            Text(
              'Произошла ошибка',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              _errorMessage ?? 'Неизвестная ошибка',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingL),
            AppButton.primary(
              text: 'Попробовать снова',
              onPressed: _loadChats,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  /// Строит основное содержимое экрана
  Widget _buildContent(ThemeData theme) {
    final filteredChats = _getFilteredChats();

    // Если у пользователя нет сообщений
    if (_chats.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Если нет результатов поиска
    if (filteredChats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppConstants.paddingM),
              Text(
                'Ничего не найдено',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingS),
              Text(
                'Попробуйте изменить поисковый запрос',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppConstants.paddingS),
        itemCount: filteredChats.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chat = filteredChats[index];
          return _buildChatItem(theme, chat);
        },
      ),
    );
  }

  /// Строит элемент списка чатов
  Widget _buildChatItem(ThemeData theme, ChatPreview chat) {
    // Форматируем время
    final formatter = DateFormat.Hm(); // Для сегодняшних сообщений
    final formatterDate = DateFormat.MMMd(); // Для более старых сообщений

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      chat.timestamp.year,
      chat.timestamp.month,
      chat.timestamp.day,
    );

    String formattedTime;
    if (messageDate == today) {
      formattedTime = formatter.format(chat.timestamp);
    } else {
      formattedTime = formatterDate.format(chat.timestamp);
    }

    // Определяем цвет иконки роли пользователя
    Color roleColor;
    IconData roleIcon;

    switch (chat.userRole) {
      case UserRole.client:
        roleColor = theme.colorScheme.primary;
        roleIcon = Icons.person;
        break;
      case UserRole.cleaner:
        roleColor = const Color(0xFFFFCB33); // Желтый
        roleIcon = Icons.cleaning_services;
        break;
      case UserRole.support:
        roleColor = const Color(0xFF28C76F); // Зеленый
        roleIcon = Icons.support_agent;
        break;
      default:
        roleColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
        roleIcon = Icons.person;
    }

    return Dismissible(
      key: Key(chat.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppConstants.paddingL),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.primary,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppConstants.paddingL),
        child: const Icon(Icons.notifications, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Удаление чата
          return await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Удалить диалог?'),
                  content: const Text(
                    'Диалог будет удален из вашего списка. Вы уверены?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
          );
        } else {
          // Настройка уведомлений
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Настройки уведомлений'),
              duration: Duration(seconds: 1),
            ),
          );
          return false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // Сохраняем удаленный чат для возможного восстановления
          final deletedChat = chat;

          setState(() {
            _chats.removeWhere((c) => c.id == chat.id);
            _lastDeletedChat = deletedChat;
          });

          // Сохраняем чат в сервисе сообщений для возможности восстановления
          _messagingService.saveDeletedChat(deletedChat.toJson());

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Диалог удален'),
              action: SnackBarAction(
                label: 'Отменить',
                onPressed: () {
                  // Реализуем восстановление удаленного чата
                  setState(() {
                    if (_lastDeletedChat != null) {
                      _chats.add(_lastDeletedChat!);
                      // Сортируем чаты по времени
                      _chats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                      _lastDeletedChat = null;
                    }
                  });

                  // Очищаем сохраненный чат в сервисе
                  _messagingService.clearLastDeletedChat();
                },
              ),
            ),
          );
        }
      },
      child: InkWell(
        onTap: () {
          // Переход к диалогу
          context.pushNamed('chat', pathParameters: {'chatId': chat.id});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingM,
            horizontal: AppConstants.paddingS,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Аватар пользователя
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          chat.userAvatar == null
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : null,
                      image:
                          chat.userAvatar != null
                              ? DecorationImage(
                                image: NetworkImage(chat.userAvatar!),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    child:
                        chat.userAvatar == null
                            ? Center(
                              child: Icon(
                                chat.userRole == UserRole.support
                                    ? Icons.support_agent
                                    : Icons.person,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            )
                            : null,
                  ),

                  // Индикатор онлайн
                  if (chat.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF28C76F), // Зеленый
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                  // Индикатор роли пользователя
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: roleColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(roleIcon, color: Colors.white, size: 10),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: AppConstants.paddingM),

              // Информация о сообщении
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Имя пользователя и время
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat.userName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight:
                                  chat.unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingS),
                        Text(
                          formattedTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                chat.unreadCount > 0
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                            fontWeight:
                                chat.unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),

                    // Объект (если есть)
                    if (chat.propertyTitle != null) ...[
                      const SizedBox(height: AppConstants.paddingXS / 2),
                      Row(
                        children: [
                          Icon(
                            Icons.home,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppConstants.paddingXS),
                          Expanded(
                            child: Text(
                              chat.propertyTitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppConstants.paddingXS),

                    // Текст последнего сообщения
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.lastMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  chat.unreadCount > 0
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              fontWeight:
                                  chat.unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: AppConstants.paddingS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.paddingS,
                              vertical: AppConstants.paddingXS / 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusS,
                              ),
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит состояние при отсутствии сообщений
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingL),
            Text(
              'У вас пока нет сообщений',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Здесь будут отображаться ваши диалоги с гостями, клинерами и службой поддержки',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingL),
            AppButton.primary(
              text: 'Связаться с поддержкой',
              onPressed: () async {
                // Реализуем переход к чату с поддержкой
                if (_user == null) return;

                try {
                  // Создаем или получаем ID чата с поддержкой
                  final supportChatId = await _messagingService
                      .createSupportChat(_user!.id);

                  if (supportChatId != null && mounted) {
                    // Переходим к чату с поддержкой
                    context.pushNamed(
                      'chat',
                      pathParameters: {'chatId': supportChatId},
                    );
                  }
                } catch (e) {
                  debugPrint('Ошибка при создании чата с поддержкой: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Не удалось подключиться к поддержке'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: Icons.support_agent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Модель для предварительного просмотра чата
class ChatPreview {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String? propertyId;
  final String? propertyTitle;
  final String? propertyImage;
  final UserRole userRole;

  ChatPreview({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
    this.propertyId,
    this.propertyTitle,
    this.propertyImage,
    required this.userRole,
  });
}

/// Расширение для преобразования ChatPreview в JSON
extension ChatPreviewToJson on ChatPreview {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'lastMessage': lastMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'propertyImage': propertyImage,
      'userRole': userRole.toString(),
    };
  }
}
