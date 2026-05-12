import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/organization_business_kind.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/navigation/subscription_tariff_route.dart';
import 'approval_request_screen.dart';
import '../../../clients/presentation/screens/client_detail_screen.dart';
import '../../../orders/presentation/screens/confirm_correct_order_screen.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../orders/presentation/widgets/order_detail_panel.dart';
import '../widgets/authenticated_chat_image.dart';
import '../widgets/authenticated_profile_avatar.dart';

export '../../ensure_chat_data_loaded.dart';

/// Включить подробные логи для сравнения first open / switch chat / resume. Выключить после локализации бага.
const bool _kChatOrderDebug = kDebugMode;

String _orderChatKindCaption(Order order) {
  final k = OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind);
  final m = OrganizationBusinessKindCodes.schedulingModeShortLabel(order.organizationSchedulingMode);
  if (k.isEmpty && m.isEmpty) return '';
  if (k.isEmpty) return 'Запись: $m';
  if (m.isEmpty) return k;
  return '$k · Запись: $m';
}

void _chatOrderLog(String scene, String message, [Map<String, Object?>? data]) {
  if (!_kChatOrderDebug) return;
  final sb = StringBuffer('[ChatOrderDebug] $scene | $message');
  if (data != null && data.isNotEmpty) {
    sb.write(' | ');
    sb.write(data.entries.map((e) => '${e.key}=${e.value}').join(', '));
  }
  debugPrint(sb.toString());
}

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  /// При открытии из карточки заказа — показываем весь чат и прокручиваем к этому заказу.
  final String? currentOrderId;
  /// Встроен в layout «список слева — чат справа»: чат на всю ширину правой панели, без ограничения maxWidth.
  final bool embeddedInSplit;
  /// Если задан — показывается кнопка «назад» в AppBar и по нажатию вызывается этот callback (оверлей поверх карточки заказа).
  final VoidCallback? onBack;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.currentOrderId,
    this.embeddedInSplit = false,
    this.onBack,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

/// Режим оверлея «добавить/редактировать работы» в центре диалога.
enum _ApprovalOverlayMode { list, newOrder, editOrder }

/// Круглая кнопка «назад» для оверлея чата поверх карточки заказа; подсвечивается при наведении.
class _OverlayBackButton extends StatefulWidget {
  const _OverlayBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_OverlayBackButton> createState() => _OverlayBackButtonState();
}

class _OverlayBackButtonState extends State<_OverlayBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: IconButton(
        onPressed: widget.onPressed,
        icon: Icon(
          Icons.arrow_back_rounded,
          color: _hover ? AppColorsDesktop.primary : AppColorsDesktop.textSecondary,
        ),
        style: IconButton.styleFrom(
          backgroundColor: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.1) : null,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey _scrollToOrderKey = GlobalKey();
  bool _didScrollToOrder = false;
  String? _overlayOrderId;
  _ApprovalOverlayMode? _approvalOverlayMode;
  String? _approvalOverlayOrderId;
  /// Временный workaround: один повторный вызов _loadChatData (путь как при resume), если при первом build часть orderId не зарезолвилась.
  String? _resumePathWorkaroundChatId;
  /// Номер build для лога сцены (first open vs resume).
  int _buildNumber = 0;
  /// Кэш chatOrders для текущего chatId: при build с chatOrdersCount=0 (глюк провайдера) подставляем последние непустые, чтобы сразу видеть полный вид как после resume.
  List<Order> _cachedChatOrders = [];
  String? _cachedChatOrdersChatId;

  /// Обновляет данные чата (заказы + сообщения). Вызывается при открытии, по WS, после отправки/согласования.
  Future<void> _loadChatData() async {
    final chatId = widget.chatId;
    _chatOrderLog('_loadChatData', 'START', {'chatId': chatId});
    await ref.read(orderRepositoryProvider.notifier).loadFromApi();
    if (!mounted) return;
    final ordersCount = ref.read(orderRepositoryProvider).length;
    _chatOrderLog('_loadChatData', 'after loadFromApi orders', {'chatId': chatId, 'ordersCount': ordersCount});
    await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(chatId);
    if (!mounted) return;
    await ref.read(chatRepositoryProvider.notifier).markChatRead(chatId);
    if (!mounted) return;
    final msgs = ref.read(chatRepositoryProvider).messages[chatId] ?? [];
    final orderIdsInMsgs = msgs.map((m) => m.orderId?.trim()).whereType<String>().where((s) => s.isNotEmpty).toSet();
    _chatOrderLog('_loadChatData', 'END', {
      'chatId': chatId,
      'messagesCount': msgs.length,
      'uniqueOrderIdsInMessages': orderIdsInMsgs.length,
      'ordersCount': ref.read(orderRepositoryProvider).length,
    });
    if (widget.currentOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToOrderIfNeeded());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _scrollToBottom();
        });
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _chatOrderLog('SCENE', 'initState → первый вход в диалог', {'chatId': widget.chatId});
    _chatOrderLog('initState', 'ChatDetailScreen', {'chatId': widget.chatId});
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChatData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatOrderLog('didChangeDependencies', 'ChatDetailScreen', {'chatId': widget.chatId});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _chatOrderLog('didChangeAppLifecycleState', 'state=$state', {'chatId': widget.chatId});
    if (state == AppLifecycleState.resumed && mounted) {
      _chatOrderLog('SCENE', 'didChangeAppLifecycleState.resumed → сворачивание/разворачивание → _loadChatData', {'chatId': widget.chatId});
      _chatOrderLog('didChangeAppLifecycleState', 'calling _loadChatData (resume path)', {'chatId': widget.chatId});
      _loadChatData();
    }
  }

  @override
  void didUpdateWidget(covariant ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chatOrderLog('didUpdateWidget', 'oldChatId=${oldWidget.chatId} newChatId=${widget.chatId}', {'chatId': widget.chatId});
    if (oldWidget.chatId != widget.chatId) {
      _resumePathWorkaroundChatId = null;
      _cachedChatOrders = [];
      _cachedChatOrdersChatId = null;
      _chatOrderLog('SCENE', 'didUpdateWidget → смена чата', {'oldChatId': oldWidget.chatId, 'newChatId': widget.chatId});
      _chatOrderLog('didUpdateWidget', 'chatId changed, scheduling _loadChatData (switch path)', {'chatId': widget.chatId});
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadChatData());
    }
    if (oldWidget.currentOrderId != widget.currentOrderId) {
      _didScrollToOrder = false;
      if (widget.currentOrderId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToOrderIfNeeded());
      }
    }
  }

  void _scrollToOrderIfNeeded() async {
    if (!mounted || _didScrollToOrder || widget.currentOrderId == null || !_scrollController.hasClients) return;
    final state = ref.read(chatRepositoryProvider);
    final orders = ref.read(orderRepositoryProvider);
    final chat = state.chats.where((c) => c.id == widget.chatId).firstOrNull;
    if (chat == null) return;
    final messages = (state.messages[widget.chatId] ?? [])..sort((a, b) => a.at.compareTo(b.at));
    final chatPhoneNorm = _normalizePhone(chat.clientPhone);
    final chatOrders = orders.where((o) {
      final p = _normalizePhone(o.clientPhone ?? '');
      return p.isNotEmpty && p == chatPhoneNorm;
    }).toList();
    final timeline = _buildTimeline(chatOrders, messages);
    final targetIndex = _indexOfOrderInTimeline(timeline, widget.currentOrderId!);
    if (targetIndex < 0) return;
    _didScrollToOrder = true;
    const estimatedItemHeight = 200.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final offset = (targetIndex * estimatedItemHeight).clamp(0.0, maxExtent);
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _scrollToOrderKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.25,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  static int _indexOfOrderInTimeline(List<_TimelineItem> timeline, String orderId) {
    for (var i = 0; i < timeline.length; i++) {
      final item = timeline[i];
      if (item.isOrder && item.order?.id == orderId) return i;
      if (item.message != null && item.message!.orderId == orderId) return i;
    }
    return -1;
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    final ok = await ref.read(chatRepositoryProvider.notifier).sendMessage(widget.chatId, text);
    if (!mounted) return;
    _scrollToBottom();
    if (!ok && mounted) {
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить сообщение. Проверьте сеть.')),
      );
    }
  }

  Future<void> _pickAndSendChatImages() async {
    final imgs = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (!mounted || imgs.isEmpty) return;
    final outgoing = <ChatOutgoingImage>[];
    for (final x in imgs) {
      final b = await x.readAsBytes();
      final name = x.name.isNotEmpty ? x.name : 'image.jpg';
      outgoing.add(ChatOutgoingImage(bytes: b, filename: name));
    }
    final text = _controller.text.trim();
    final err = await ref.read(chatRepositoryProvider.notifier).sendMessageWithMedia(
          widget.chatId,
          text: text,
          images: outgoing,
        );
    if (!mounted) return;
    if (err == null) {
      _controller.clear();
      _scrollToBottom();
    } else {
      final lower = err.toLowerCase();
      final showTariff = lower.contains('тариф') ||
          lower.contains('подписк') ||
          lower.contains('лимит') ||
          lower.contains('изображен');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          duration: const Duration(seconds: 8),
          action: showTariff
              ? SnackBarAction(
                  label: 'Тариф',
                  onPressed: () => openSubscriptionTariffScreen(context),
                )
              : null,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      maxExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_scrollController.hasClients) return;
      final again = _scrollController.position.maxScrollExtent;
      if (again > 0 && (_scrollController.offset < again - 20)) {
        _scrollController.animateTo(again, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _insertTemplate(String body) {
    if (_controller.text.isNotEmpty) _controller.text += '\n';
    _controller.text += body;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
  }

  /// Активные статусы заказа (не завершён и не отменён).
  static bool _isOrderActive(Order order) => order.status.isActive;

  /// Строка похожа на UUID — не показывать пользователю.
  static bool _looksLikeUuid(String s) =>
      s.length > 20 && s.contains('-') && RegExp(r'^[0-9a-fA-F-]{30,}$').hasMatch(s);

  /// Нормализация телефона для сравнения (8/7 и только цифры — одна форма).
  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) return '7${digits.substring(1)}';
    return digits;
  }

  /// Системное сообщение после заявки клиента (см. orders.service addSystemMessage).
  static bool _isClientCreatedOrderSystemMessage(String content) {
    return content.toLowerCase().contains('клиент создал заявку');
  }

  /// Текст для сотрудников: подменяем «ожидает проверку» на актуальный этап по статусу заказа (история в БД не меняется).
  static String _stoBookingStatusSystemText(String original, ChatMessage message, List<Order> chatOrders) {
    if (!_isClientCreatedOrderSystemMessage(original)) return original;
    final orderId = message.orderId?.trim();
    if (orderId == null || orderId.isEmpty) return original;
    final order = chatOrders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return original;
    switch (order.status) {
      case OrderStatus.pendingConfirmation:
        return 'Клиент создал заявку. Требуется подтверждение или проверка.';
      case OrderStatus.pendingApproval:
        return 'Заявка отправлена клиенту на согласование.';
      case OrderStatus.confirmed:
        return 'Заявка подтверждена.';
      case OrderStatus.inProgress:
        return 'Заявка подтверждена. Заказ в работе.';
      case OrderStatus.completed:
        return 'Заказ готов к выдаче.';
      case OrderStatus.done:
        return 'Заказ завершён.';
      case OrderStatus.cancelled:
        return 'Заявка отменена.';
    }
  }

  Future<void> _onRequestApproval(BuildContext context, ChatPreview chat, List<Order> chatOrdersFromBuild) async {
    await ref.read(orderRepositoryProvider.notifier).loadFromApi();
    if (!context.mounted) return;
    ChatPreview currentChat = chat;
    var chatPhoneNorm = _normalizePhone(currentChat.clientPhone);
    if (chatPhoneNorm.isEmpty) {
      await ref.read(chatRepositoryProvider.notifier).loadFromApi();
      if (!context.mounted) return;
      final updatedChat = ref.read(chatRepositoryProvider).chats.where((c) => c.id == currentChat.id).firstOrNull;
      if (updatedChat != null) currentChat = updatedChat;
      chatPhoneNorm = _normalizePhone(currentChat.clientPhone);
    }
    var orders = ref.read(orderRepositoryProvider);
    final chatOrders = orders.where((o) {
      final p = _normalizePhone(o.clientPhone ?? '');
      return p.isNotEmpty && p == chatPhoneNorm;
    }).toList();
    final activeOrders = chatOrders.where(_isOrderActive).toList();
    final orgId = ref.read(authProvider).user?.organizationId ?? '';
    if (kDebugMode) {
      // ignore: avoid_print
      print('[approval_sheet] totalOrders=${orders.length} activeOrders=${activeOrders.length} phone=$chatPhoneNorm orgId=$orgId');
    }
    if (!context.mounted) return;
    // Открываем оверлей в центре диалога (список заказов или создание нового).
    setState(() {
      _approvalOverlayMode = _ApprovalOverlayMode.list;
      _approvalOverlayOrderId = null;
    });
  }

  void _closeApprovalOverlay() {
    setState(() {
      _approvalOverlayMode = null;
      _approvalOverlayOrderId = null;
    });
  }

  void _openOrderDetail(BuildContext context, String orderId, bool isDesktop) {
    if (isDesktop) {
      setState(() => _overlayOrderId = orderId);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: orderId),
        ),
      ).then((_) {
        if (!mounted) return;
        ref.read(orderRepositoryProvider.notifier).loadFromApi();
        ref.read(chatRepositoryProvider.notifier).loadMessagesFor(widget.chatId);
      });
    }
  }

  void _showTemplates() {
    final templates = ref.read(settingsRepositoryProvider).messageTemplates;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Шаблоны сообщений',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            if (templates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Нет шаблонов. Добавьте в Настройки.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (ctx, i) {
                  final t = templates[i];
                  return ListTile(
                    title: Text(t.title),
                    subtitle: Text(
                      t.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _insertTemplate(t.body);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildNumber += 1;
    final state = ref.watch(chatRepositoryProvider);
    final chat = state.chats.where((c) => c.id == widget.chatId).firstOrNull;
    final isDesktop = isDesktopPlatform;
    final List<ChatMessage> messages = (List<ChatMessage>.from(state.messages[widget.chatId] ?? [])..sort((a, b) => a.at.compareTo(b.at)));
    if (chat == null) {
      _chatOrderLog('SCENE', 'build #$_buildNumber | chat=null → Чат не найден', {'chatId': widget.chatId});
      return Scaffold(
        appBar: AppBar(title: const Text('Чат')),
        body: const Center(child: Text('Чат не найден')),
      );
    }
    List<Order> chatOrders = ref.watch(orderRepositoryProvider).where((o) {
      final p = _normalizePhone(o.clientPhone ?? '');
      final chatPhoneNorm = _normalizePhone(chat.clientPhone);
      return p.isNotEmpty && p == chatPhoneNorm;
    }).toList();
    final allOrders = ref.read(orderRepositoryProvider);

    if (chatOrders.isNotEmpty) {
      _cachedChatOrders = List.from(chatOrders);
      _cachedChatOrdersChatId = widget.chatId;
    } else if (_cachedChatOrdersChatId == widget.chatId && _cachedChatOrders.isNotEmpty) {
      _chatOrderLog('SCENE', 'build #$_buildNumber | chatOrders=0 → используем кэш (${_cachedChatOrders.length} заказов)', {
        'chatId': widget.chatId,
        'chatClientPhone': chat.clientPhone.isEmpty ? '(пусто)' : '${chat.clientPhone.substring(0, chat.clientPhone.length.clamp(0, 6))}...',
      });
      chatOrders = _cachedChatOrders;
    } else if (allOrders.isNotEmpty) {
      _chatOrderLog('SCENE', 'build #$_buildNumber | WARN: chatOrdersCount=0 при allOrdersCount=${allOrders.length}', {
        'chatId': widget.chatId,
        'chatClientPhone': chat.clientPhone.isEmpty ? '(пусто)' : chat.clientPhone,
      });
    }

    final orderIdsInMessages = messages.map((m) => m.orderId?.trim()).whereType<String>().where((s) => s.isNotEmpty).toSet();
    final resolvedCount = orderIdsInMessages.where((id) => allOrders.any((o) => o.id == id)).length;
    final unresolvedCount = orderIdsInMessages.length - resolvedCount;
    _chatOrderLog('SCENE', 'build #$_buildNumber', {
      'chatId': widget.chatId,
      'messagesCount': messages.length,
      'chatOrdersCount': chatOrders.length,
      'allOrdersCount': allOrders.length,
      'orderIdsResolved': resolvedCount,
    });
    _chatOrderLog('build', 'ChatDetailScreen', {
      'chatId': widget.chatId,
      'messagesCount': messages.length,
      'uniqueOrderIdsInMessages': orderIdsInMessages.length,
      'chatOrdersCount': chatOrders.length,
      'allOrdersCount': allOrders.length,
      'orderIdsResolved': resolvedCount,
      'orderIdsUnresolved': unresolvedCount,
    });
    if (orderIdsInMessages.isNotEmpty &&
        unresolvedCount > 0 &&
        _resumePathWorkaroundChatId != widget.chatId &&
        mounted) {
      _resumePathWorkaroundChatId = widget.chatId;
      _chatOrderLog('build', 'WORKAROUND: scheduling _loadChatData (resume path) once', {'chatId': widget.chatId});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _resumePathWorkaroundChatId == widget.chatId) _loadChatData();
      });
    }
    final timeline = _buildTimeline(chatOrders, messages);
    final activeOrders = chatOrders.where(_isOrderActive).toList();
    final completedOrders = chatOrders.where((o) => !_isOrderActive(o)).toList();
    final latestApprovalIdPerOrder = _latestApprovalMessageIdPerOrder(messages);
    List<ApprovalItem>? overlayFallbackItems;
    int? overlayFallbackTotalKopecks;
    int? overlayFallbackTotalMinutes;
    if (_overlayOrderId != null && isDesktop) {
      final approvalMsg = _getLatestApprovalMessageForOrder(timeline, _overlayOrderId!);
      if (approvalMsg != null) {
        overlayFallbackItems = _itemsFromApprovalMessage(approvalMsg);
        overlayFallbackTotalKopecks = approvalMsg.totalsAfterPriceKopecks ?? approvalMsg.approvalTotalKopecks;
        overlayFallbackTotalMinutes = approvalMsg.totalsAfterMinutes ?? approvalMsg.approvalTotalMinutes;
      }
    }
    const kDesktopChatMaxWidth = 480.0;
    final useFullWidth = widget.embeddedInSplit;
    final isSupport = chat.isSupportChat;

    return Scaffold(
      backgroundColor: isDesktop ? AppColorsDesktop.background : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDesktop ? AppColorsDesktop.surface : null,
        foregroundColor: isDesktop ? AppColorsDesktop.textPrimary : null,
        elevation: isDesktop ? 0 : null,
        leading: widget.onBack != null
            ? _OverlayBackButton(onPressed: widget.onBack!)
            : null,
        title: isSupport
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Поддержка MP-Servis',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 20,
                      fontWeight: FontWeight.w600,
                      color: isDesktop ? AppColorsDesktop.textPrimary : null,
                    ),
                  ),
                  Text(
                    'Служба поддержки',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  AuthenticatedProfileAvatar(
                    imageUrl: chat.clientAvatarUrl,
                    fallbackLetter: chat.clientName.isNotEmpty ? chat.clientName[0] : '?',
                    size: isDesktop ? 36 : 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientDetailScreen(
                              clientName: chat.clientName.isNotEmpty ? chat.clientName : 'Клиент',
                              clientPhone: chat.clientPhone.isNotEmpty ? chat.clientPhone : null,
                              clientAvatarUrl: chat.clientAvatarUrl,
                              orders: chatOrders,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(chat.clientName.isNotEmpty ? chat.clientName : 'Клиент'),
                          Text(
                            'Чат с клиентом',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          if (!isSupport)
            IconButton(
              icon: const Icon(Icons.request_quote_rounded),
              tooltip: 'Запросить согласование',
              onPressed: () => _onRequestApproval(context, chat, chatOrders),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildChatListView(
                  context: context,
                  timeline: timeline,
                  chatOrders: chatOrders,
                  latestApprovalIdPerOrder: latestApprovalIdPerOrder,
                  isDesktop: isDesktop,
                  useFullWidth: useFullWidth,
                  kDesktopChatMaxWidth: kDesktopChatMaxWidth,
                  onOrderTap: (orderId) => _openOrderDetail(context, orderId, isDesktop),
                  scrollToOrderKey: widget.currentOrderId != null ? _scrollToOrderKey : null,
                  isSupportChat: isSupport,
                  clientAvatarUrl: chat.clientAvatarUrl,
                  clientNameForAvatar: chat.clientName.isNotEmpty ? chat.clientName : 'Клиент',
                ),
                if (_overlayOrderId != null && isDesktop) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _overlayOrderId = null),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(color: Colors.black26),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: MediaQuery.sizeOf(context).height * 0.85,
                          width: 520,
                          decoration: BoxDecoration(
                            color: AppColorsDesktop.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: OrderDetailPanel(
                            orderId: _overlayOrderId!,
                            onClose: () => setState(() => _overlayOrderId = null),
                            fallbackItems: overlayFallbackItems,
                            fallbackTotalKopecks: overlayFallbackTotalKopecks,
                            fallbackTotalMinutes: overlayFallbackTotalMinutes,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_approvalOverlayMode != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _approvalOverlayMode == _ApprovalOverlayMode.list ? _closeApprovalOverlay : null,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(color: Colors.black38),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: _ApprovalOverlayContent(
                        mode: _approvalOverlayMode!,
                        orderId: _approvalOverlayOrderId,
                        chatId: widget.chatId,
                        activeOrders: activeOrders,
                        completedOrders: completedOrders,
                        onClose: _closeApprovalOverlay,
                        onBackToList: () => setState(() {
                          _approvalOverlayMode = _ApprovalOverlayMode.list;
                          _approvalOverlayOrderId = null;
                        }),
                        onSelectNewOrder: () => setState(() => _approvalOverlayMode = _ApprovalOverlayMode.newOrder),
                        onSelectEditOrder: (String orderId) => setState(() {
                          _approvalOverlayMode = _ApprovalOverlayMode.editOrder;
                          _approvalOverlayOrderId = orderId;
                        }),
                        isDesktop: isDesktop,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final canWrite = ref.watch(authProvider).user?.effectiveCanWriteChats ?? false;
              if (!canWrite) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDesktop ? AppColorsDesktop.surface : AppColors.cardBg,
                    border: isDesktop ? const Border(top: BorderSide(color: AppColorsDesktop.border)) : null,
                  ),
                  child: SafeArea(
                    child: Text(
                      'У вас нет права отправлять сообщения в чатах. Обратитесь к администратору организации.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDesktop ? AppColorsDesktop.surface : AppColors.cardBg,
                  border: isDesktop ? const Border(top: BorderSide(color: AppColorsDesktop.border)) : null,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      if (!isSupport)
                        IconButton(
                          icon: const Icon(Icons.short_text_rounded),
                          tooltip: 'Шаблоны',
                          onPressed: _showTemplates,
                        ),
                      IconButton(
                        icon: const Icon(Icons.photo_library_outlined),
                        tooltip: 'Фото из галереи',
                        onPressed: _pickAndSendChatImages,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Сообщение',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatListView({
    required BuildContext context,
    required List<_TimelineItem> timeline,
    required List<Order> chatOrders,
    required Map<String, String> latestApprovalIdPerOrder,
    required bool isDesktop,
    required bool useFullWidth,
    required double kDesktopChatMaxWidth,
    required void Function(String orderId) onOrderTap,
    GlobalKey? scrollToOrderKey,
    required bool isSupportChat,
    String? clientAvatarUrl,
    String clientNameForAvatar = 'Клиент',
  }) {
    final listView = ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: timeline.length,
      itemBuilder: (context, i) {
        final item = timeline[i];
        final prevAt = i > 0 ? timeline[i - 1].sortAt : null;
        final showDate = prevAt == null ||
            item.sortAt.day != prevAt.day ||
            item.sortAt.month != prevAt.month ||
            item.sortAt.year != prevAt.year;
        if (item.isOrder) {
          final order = item.order!;
          final createdViaApproval = _orderCreatedViaApprovalFromSto(timeline, order.id);
          if ((order.status == OrderStatus.pendingConfirmation || order.status == OrderStatus.pendingApproval) && createdViaApproval) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [if (showDate) _DateSeparator(date: item.sortAt, isDesktop: isDesktop)],
            );
          }
          final latestApprovalMsg = _getLatestApprovalMessageForOrder(timeline, order.id);
          final fallbackItems = latestApprovalMsg != null ? _itemsFromApprovalMessage(latestApprovalMsg) : null;
          final fallbackTotal = latestApprovalMsg?.totalsAfterPriceKopecks ?? latestApprovalMsg?.approvalTotalKopecks;
          final card = order.status == OrderStatus.pendingConfirmation
              ? _OrderFullCard(
                  order: order,
                  isDesktop: isDesktop,
                  onTap: () => _openOrderDetail(context, order.id, isDesktop),
                  approvalFallbackItems: fallbackItems,
                  approvalFallbackTotalKopecks: fallbackTotal,
                )
              : _OrderTimelineCard(
                  order: order,
                  isDesktop: isDesktop,
                  onTap: () => _openOrderDetail(context, order.id, isDesktop),
                );
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDate) _DateSeparator(date: item.sortAt, isDesktop: isDesktop),
              _AnimatedChatCard(key: ValueKey('order_${order.id}_$i'), child: card),
            ],
          );
          final isTargetOrder = scrollToOrderKey != null && order.id == widget.currentOrderId;
          return isTargetOrder ? KeyedSubtree(key: scrollToOrderKey, child: column) : column;
        }
        final m = item.message!;
        final msgOrderId = m.orderId?.trim() ?? '';
        final hasOrderLink = msgOrderId.isNotEmpty;

        if (m.isApprovalCard) {
          final orderForMsg = hasOrderLink ? chatOrders.where((o) => o.id == msgOrderId).firstOrNull : null;
          final isPending = orderForMsg?.status == OrderStatus.pendingApproval || orderForMsg?.status == OrderStatus.pendingConfirmation
              || m.approvalStatus == null || m.approvalStatus == ApprovalStatus.pending;
          final isLatest = latestApprovalIdPerOrder[msgOrderId] == m.id;
          final orderShownAsCard = orderForMsg?.status == OrderStatus.pendingApproval || orderForMsg?.status == OrderStatus.pendingConfirmation;
          final createdViaApproval = hasOrderLink && _orderCreatedViaApprovalFromSto(timeline, msgOrderId);
          final showApprovalCard = isPending && isLatest && (!orderShownAsCard || createdViaApproval);
          if (!showApprovalCard) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate) _DateSeparator(date: item.sortAt, isDesktop: isDesktop),
                if (hasOrderLink) _OrderLinkInline(orderId: msgOrderId, onOrderTap: onOrderTap, isDesktop: isDesktop, prominent: false),
              ],
            );
          }
        }
        if (m.isBookingCard) {
          final orderAlreadyShown = chatOrders.any((o) => o.id == msgOrderId);
          if (orderAlreadyShown) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [if (showDate) _DateSeparator(date: item.sortAt, isDesktop: isDesktop)],
            );
          }
        }
        Widget content;
        if (m.isSystem) {
          final systemText = _stoBookingStatusSystemText(m.text, m, chatOrders);
          content = _buildSystemMessageBubble(systemText, isDesktop);
        } else if (m.isBookingCard) {
          content = _OrderLinkInline(orderId: msgOrderId, onOrderTap: onOrderTap, isDesktop: isDesktop, prominent: false);
        } else if (m.isApprovalCard) {
          content = _ApprovalCard(
            message: m,
            chatId: widget.chatId,
            isDesktop: isDesktop,
            onResponse: () => _scrollToBottom(),
            onOrderTap: onOrderTap,
          );
        } else {
          content = _buildMessageBubble(
            context,
            m,
            isDesktop,
            isSupportChat,
            clientAvatarUrl: clientAvatarUrl,
            clientNameForAvatar: clientNameForAvatar,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _DateSeparator(date: item.sortAt, isDesktop: isDesktop),
            _AnimatedChatCard(key: ValueKey('msg_${m.id}_$i'), child: content),
          ],
        );
      },
    );
    if (useFullWidth) return listView;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? kDesktopChatMaxWidth : double.infinity),
        child: listView,
      ),
    );
  }

  static bool _orderCreatedViaApprovalFromSto(List<_TimelineItem> timeline, String orderId) {
    for (final item in timeline) {
      if (item.message == null || !item.message!.isApprovalCard) continue;
      if (item.message!.orderId != orderId) continue;
      if (item.message!.isFromClient) continue;
      return true;
    }
    return false;
  }

  static ChatMessage? _getLatestApprovalMessageForOrder(List<_TimelineItem> timeline, String orderId) {
    ChatMessage? latest;
    for (final item in timeline) {
      if (item.message == null || !item.message!.isApprovalCard) continue;
      if (item.message!.orderId != orderId) continue;
      if (latest == null || item.message!.at.isAfter(latest.at)) latest = item.message;
    }
    return latest;
  }

  static List<ApprovalItem> _itemsFromApprovalMessage(ChatMessage m) {
    final list = <ApprovalItem>[];
    if (m.originalApprovalItems != null) list.addAll(m.originalApprovalItems!);
    if (m.editedApprovalItems != null) {
      for (final e in m.editedApprovalItems!) {
        list.add(ApprovalItem(name: e.name, priceKopecks: e.priceKopecks, estimatedMinutes: e.estimatedMinutes));
      }
    }
    if (m.newApprovalItems != null) list.addAll(m.newApprovalItems!);
    if (m.approvalItems != null && list.isEmpty) list.addAll(m.approvalItems!);
    return list;
  }

  static List<_TimelineItem> _buildTimeline(List<Order> chatOrders, List<ChatMessage> messages) {
    final items = <_TimelineItem>[
      ...chatOrders.map((o) => _TimelineItem.order(o)),
      ...messages.map((m) => _TimelineItem.message(m)),
    ];
    items.sort((a, b) => a.sortAt.compareTo(b.sortAt));
    return items;
  }

  /// Для каждого orderId — id последнего по времени approval-сообщения (чтобы показывать только его, историю скрывать).
  static Map<String, String> _latestApprovalMessageIdPerOrder(List<ChatMessage> messages) {
    final approvalByOrder = <String, ChatMessage>{};
    for (final m in messages) {
      if (!m.isApprovalCard) continue;
      final oid = m.orderId ?? '';
      if (oid.isEmpty) continue;
      final existing = approvalByOrder[oid];
      if (existing == null || m.at.isAfter(existing.at)) {
        approvalByOrder[oid] = m;
      }
    }
    return approvalByOrder.map((k, v) => MapEntry(k, v.id));
  }

  /// Системное сообщение: по центру, нейтральный серый текст (как в Telegram).
  static Widget _buildSystemMessageBubble(String text, bool isDesktop) {
    final color = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage m,
    bool isDesktop,
    bool isSupportChat, {
    String? clientAvatarUrl,
    String clientNameForAvatar = 'Клиент',
  }) {
    final fromSupportOperator =
        m.isFromSupportOperator || m.messageType == 'support_operator_reply';
    final isMe = !isSupportChat
        ? !m.isFromClient
        : (!fromSupportOperator && (m.isFromClient || m.supportChannel == 'business'));
    final maxW = isDesktop ? 440.0 : MediaQuery.sizeOf(context).width * 0.8;
    final bubbleColor = isMe
        ? (isDesktop ? AppColorsDesktop.primary : AppColors.primary)
        : (isDesktop ? AppColorsDesktop.surface : AppColors.cardBg);
    final textColor = isMe
        ? (isDesktop ? Colors.white : const Color(0xFF0D0D0D))
        : (isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary);
    final timeColor = isMe
        ? (isDesktop ? Colors.white70 : const Color(0xFF0D0D0D).withValues(alpha: 0.7))
        : (isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary);
    final border = isMe ? null : Border.all(color: isDesktop ? AppColorsDesktop.border : AppColors.border);
    final atts = m.attachments;
    final hasText = m.text.trim().isNotEmpty;
    final showClientAvatar = !isSupportChat && !isMe;
    final letter = clientNameForAvatar.isNotEmpty ? clientNameForAvatar[0] : '?';
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (atts.isNotEmpty)
            ...atts.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: AuthenticatedChatImage(attachment: a, maxHeight: 160),
                ),
              ),
            ),
          if (hasText)
            Text(
              m.text,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(m.at),
            style: TextStyle(fontSize: 11, color: timeColor),
          ),
        ],
      ),
    );
    if (!showClientAvatar) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 6),
              child: AuthenticatedProfileAvatar(
                imageUrl: clientAvatarUrl,
                fallbackLetter: letter,
                size: 28,
              ),
            ),
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}

/// Список заказов в оверлее: активные, свернутые завершённые (раскрываются по стрелке), внизу фиксированная кнопка.
class _ApprovalOrderListPanel extends StatefulWidget {
  final List<Order> activeOrders;
  final List<Order> completedOrders;
  final VoidCallback onClose;
  final VoidCallback onSelectNewOrder;
  final void Function(String) onSelectEditOrder;
  final double maxW;
  final double maxH;
  final bool isDesktop;

  const _ApprovalOrderListPanel({
    required this.activeOrders,
    required this.completedOrders,
    required this.onClose,
    required this.onSelectNewOrder,
    required this.onSelectEditOrder,
    required this.maxW,
    required this.maxH,
    required this.isDesktop,
  });

  @override
  State<_ApprovalOrderListPanel> createState() => _ApprovalOrderListPanelState();
}

class _ApprovalOrderListPanelState extends State<_ApprovalOrderListPanel> {
  bool _completedExpanded = false;

  Widget _orderTile(Order order, bool isActive) {
    final firstWork = order.items.isNotEmpty ? order.items.first.name : null;
    final isDesktop = widget.isDesktop;
    final tileBg = isDesktop ? AppColorsDesktop.nestedBg : AppColors.nestedBg;
    final tileBorder = isDesktop ? AppColorsDesktop.borderLight : AppColors.borderLight;
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final primary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? () => widget.onSelectEditOrder(order.id) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tileBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.edit_note_rounded : Icons.receipt_long_rounded,
                  size: 22,
                  color: isActive ? primary : textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заказ ${order.displayNumber}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      if (firstWork != null)
                        Text(
                          firstWork,
                          style: TextStyle(fontSize: 12, color: textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: order.status.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    order.stoDisplayStatusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: order.status.color, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: textTertiary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    final isDesktop = widget.isDesktop;
    final panelBg = isDesktop ? AppColorsDesktop.surface : AppColors.cardBg;
    final panelBorder = isDesktop ? AppColorsDesktop.border : AppColors.border;
    final headerBg = isDesktop ? AppColorsDesktop.primary.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.06);
    final primary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final maxHeight = MediaQuery.sizeOf(context).height * widget.maxH;
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(radius),
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.maxW, maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: panelBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: panelBorder)),
              ),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 24, color: primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Добавить или отредактировать работы',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(foregroundColor: textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.activeOrders.isNotEmpty) ...[
                      Text(
                        'Активные заказы',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.activeOrders.map((o) => _orderTile(o, true)),
                      if (widget.completedOrders.isNotEmpty) const SizedBox(height: 16),
                    ],
                    if (widget.completedOrders.isNotEmpty) ...[
                      InkWell(
                        onTap: () => setState(() => _completedExpanded = !_completedExpanded),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _completedExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 24,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Завершённые заказы (${widget.completedOrders.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_completedExpanded) ...[
                        const SizedBox(height: 4),
                        ...widget.completedOrders.map((o) => _orderTile(o, false)),
                      ],
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: panelBg,
                border: Border(top: BorderSide(color: panelBorder)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: widget.onSelectNewOrder,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                    label: const Text('Создать новый заказ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: isDesktop ? Colors.white : AppColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Контент оверлея «добавить/редактировать работы» в центре диалога: список заказов или форма.
class _ApprovalOverlayContent extends ConsumerWidget {
  final _ApprovalOverlayMode mode;
  final String? orderId;
  final String chatId;
  final List<Order> activeOrders;
  final List<Order> completedOrders;
  final VoidCallback onClose;
  final VoidCallback onBackToList;
  final VoidCallback onSelectNewOrder;
  final void Function(String) onSelectEditOrder;
  final bool isDesktop;

  const _ApprovalOverlayContent({
    required this.mode,
    required this.chatId,
    required this.activeOrders,
    required this.completedOrders,
    required this.onClose,
    required this.onBackToList,
    required this.onSelectNewOrder,
    required this.onSelectEditOrder,
    required this.isDesktop,
    this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(
          scale: 0.94 + 0.06 * value,
          child: child,
        ),
      ),
      child: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    const radius = 20.0;
    const maxW = 420.0;
    const maxH = 0.88;

    if (mode == _ApprovalOverlayMode.list) {
      return _ApprovalOrderListPanel(
        activeOrders: activeOrders,
        completedOrders: completedOrders,
        onClose: onClose,
        onSelectNewOrder: onSelectNewOrder,
        onSelectEditOrder: onSelectEditOrder,
        maxW: maxW,
        maxH: maxH,
        isDesktop: isDesktop,
      );
    }

    final overlayBg = isDesktop ? AppColorsDesktop.surface : AppColors.cardBg;
    final overlayBorder = isDesktop ? AppColorsDesktop.border : AppColors.border;

    if (mode == _ApprovalOverlayMode.newOrder) {
      final height = MediaQuery.sizeOf(context).height * maxH;
      return Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(radius),
        color: Colors.transparent,
        child: Container(
          width: maxW,
          height: height,
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: height),
          decoration: BoxDecoration(
            color: overlayBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: overlayBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ApprovalRequestScreen(
            chatId: chatId,
            orderId: '',
            embeddedInDialog: true,
            onClose: onBackToList,
            chatOrdersForCarSelection: activeOrders + completedOrders,
          ),
        ),
      );
    }

    if (mode == _ApprovalOverlayMode.editOrder && orderId != null) {
      final height = MediaQuery.sizeOf(context).height * maxH;
      return Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(radius),
        color: Colors.transparent,
        child: Container(
          width: maxW,
          height: height,
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: height),
          decoration: BoxDecoration(
            color: overlayBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: overlayBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ConfirmCorrectOrderScreen(
            orderId: orderId!,
            chatId: chatId,
            embeddedInDialog: true,
            onClose: onBackToList,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Плавное появление карточки в ленте чата (fade + slide).
class _AnimatedChatCard extends StatelessWidget {
  final Widget child;

  const _AnimatedChatCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, c) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: c,
        ),
      ),
    );
  }
}

class _TimelineItem {
  final DateTime sortAt;
  final Order? order;
  final ChatMessage? message;
  _TimelineItem._({required this.sortAt, this.order, this.message});
  factory _TimelineItem.order(Order o) => _TimelineItem._(sortAt: o.timelineSortAt, order: o);
  factory _TimelineItem.message(ChatMessage m) => _TimelineItem._(sortAt: m.at, message: m);
  bool get isOrder => order != null;
}

/// Компактная строка-ссылка на заказ. Подписан на orderByIdProvider(orderId).
class _OrderLinkInline extends ConsumerWidget {
  final String orderId;
  final void Function(String orderId) onOrderTap;
  final bool isDesktop;
  final bool prominent;

  const _OrderLinkInline({
    required this.orderId,
    required this.onOrderTap,
    required this.isDesktop,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));
    final String label;
    if (order != null &&
        order.orderNumber.isNotEmpty &&
        !_ChatDetailScreenState._looksLikeUuid(order.orderNumber)) {
      label = 'Открыть заказ ${order.displayNumber}';
    } else {
      label = order == null ? 'Заказ загружается...' : 'Открыть заказ';
    }
    _chatOrderLog('_OrderLinkInline.build', 'resolve orderId', {
      'orderId': orderId.length > 12 ? '${orderId.substring(0, 8)}...' : orderId,
      'orderResolved': order != null,
      'orderNumber': order?.orderNumber ?? 'null',
      'label': label.startsWith('Заказ загружается') ? 'FALLBACK' : 'OK',
    });
    final primary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    final fontSize = prominent ? 16.0 : 14.0;
    final fontWeight = prominent ? FontWeight.w700 : FontWeight.w600;
    final cap = isDesktop ? 380.0 : 320.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth.clamp(0.0, cap) : cap;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: w),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOrderTap(orderId),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: prominent ? 12 : 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: prominent ? 20 : 18, color: primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: fontWeight,
                              color: primary,
                              decoration: TextDecoration.underline,
                              decorationColor: primary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.open_in_new_rounded, size: prominent ? 18 : 16, color: primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTimelineCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final bool isDesktop;

  const _OrderTimelineCard({required this.order, required this.onTap, this.isDesktop = false});

  static String _bookingTimeRange(Order order) {
    final start = order.plannedStartTime ?? order.dateTime;
    final end = order.plannedEndTime;
    final durationMin = order.items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
    final endComputed = end ?? start?.add(Duration(minutes: durationMin > 0 ? durationMin : 60));
    if (start != null && endComputed != null) {
      return '${formatTime(start)}–${formatTime(endComputed)}';
    }
    if (start != null) return formatTime(start);
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final statusColor = order.status.color;
    final isAwaitingClientApproval = order.status == OrderStatus.pendingApproval;
    const radius = 24.0;
    final range = _bookingTimeRange(order);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              constraints: BoxConstraints(maxWidth: isDesktop ? 440 : 320),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isAwaitingClientApproval
                    ? (isDesktop ? AppColorsDesktop.statusApproval : AppColors.statusApproval).withValues(alpha: 0.10)
                    : statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isAwaitingClientApproval
                      ? (isDesktop ? AppColorsDesktop.statusApproval : AppColors.statusApproval).withValues(alpha: 0.55)
                      : statusColor.withValues(alpha: 0.4),
                  width: isAwaitingClientApproval ? 1.5 : 1,
                ),
                boxShadow: isAwaitingClientApproval
                    ? [
                        BoxShadow(
                          color: (isDesktop ? AppColorsDesktop.statusApproval : AppColors.statusApproval)
                              .withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isAwaitingClientApproval) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: isDesktop ? AppColorsDesktop.statusApproval : AppColors.statusApproval,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ожидает ответа клиента',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        order.stoDisplayStatusLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 400 : 280),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              order.displayNumber,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            range,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 20, color: textTertiary),
                        ],
                      ),
                    ),
                  ),
                  if (_orderChatKindCaption(order).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _orderChatKindCaption(order),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: textTertiary, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Полноценная карточка заказа в диалоге с клиентом: перечень работ, сумма, дата и время (для заказа «Ожидает подтверждения»).
/// Если заказ создан через запрос согласования, [order.items] может быть пуст — тогда показываем [approvalFallbackItems] и [approvalFallbackTotalKopecks].
class _OrderFullCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final bool isDesktop;
  final List<ApprovalItem>? approvalFallbackItems;
  final int? approvalFallbackTotalKopecks;

  const _OrderFullCard({
    required this.order,
    required this.onTap,
    this.isDesktop = false,
    this.approvalFallbackItems,
    this.approvalFallbackTotalKopecks,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = order.items.isNotEmpty
        ? order.items
            .map((i) => ApprovalItem(
                  name: i.name,
                  priceKopecks: i.priceKopecks ?? 0,
                  estimatedMinutes: i.estimatedMinutes,
                ))
            .toList()
        : (approvalFallbackItems ?? <ApprovalItem>[]);
    final totalKopecks = order.items.isNotEmpty
        ? order.totalKopecks
        : (approvalFallbackTotalKopecks ?? displayItems.fold<int>(0, (s, i) => s + i.priceKopecks));
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final textTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final primary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    final statusColor = order.status == OrderStatus.pendingConfirmation
        ? (isDesktop ? AppColorsDesktop.statusPending : AppColors.statusPending)
        : order.status.color;
    final borderColor = isDesktop ? AppColorsDesktop.border : statusColor.withValues(alpha: 0.4);
    final bgColor = isDesktop ? AppColorsDesktop.surface : AppColors.cardBg;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 340),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              order.displayNumber,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                order.stoDisplayStatusLabel,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor, height: 1.2),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.plannedStartTime != null && order.plannedEndTime != null
                        ? '${formatDateTime(order.plannedStartTime!)} – ${formatTime(order.plannedEndTime!)}'
                        : formatDateTimeOrNull(order.dateTime),
                    style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  if (_orderChatKindCaption(order).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _orderChatKindCaption(order),
                      style: TextStyle(fontSize: 12, color: textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Блок «Автомобиль» сверху: марка, модель, поколение, год, VIN
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: (isDesktop ? AppColorsDesktop.nestedBg : AppColors.nestedBg).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDesktop ? AppColorsDesktop.border : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_car_rounded, size: 18, color: isDesktop ? AppColorsDesktop.primary : AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Автомобиль',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.carInfo.isNotEmpty ? order.carInfo : '—',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.vin != null && order.vin!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'VIN: ${order.vin!.trim()}',
                            style: TextStyle(fontSize: 12, color: textSecondary, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Гос. номер: ${order.licensePlate!.trim()}', style: TextStyle(fontSize: 12, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        if (order.color != null && order.color!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Цвет: ${order.color!.trim()}', style: TextStyle(fontSize: 12, color: textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        if (order.mileage != null && order.mileage! > 0) ...[
                          const SizedBox(height: 2),
                          Text('Пробег: ${order.mileage} км', style: TextStyle(fontSize: 12, color: textTertiary), maxLines: 1),
                        ],
                        if (order.engineType != null && order.engineType!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Двигатель: ${order.engineType!.trim()}', style: TextStyle(fontSize: 12, color: textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: isDesktop ? AppColorsDesktop.border : AppColors.border, height: 20),
                  Text(
                    'Перечень работ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ...displayItems.map((item) {
                    final durationLabel = item.estimatedMinutes >= 60
                        ? '${item.estimatedMinutes ~/ 60} ч'
                        : '${item.estimatedMinutes} мин';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(fontSize: 14, color: textPrimary),
                            ),
                          ),
                          Text(
                            formatMoney(item.priceKopecks),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                          ),
                          if (item.estimatedMinutes > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              durationLabel,
                              style: TextStyle(fontSize: 12, color: textTertiary),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Divider(color: isDesktop ? AppColorsDesktop.border : AppColors.border, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Итого',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      Text(
                        formatMoney(totalKopecks),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDesktop ? AppColorsDesktop.primary : primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 18, color: primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Открыть заказ ${order.displayNumber}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: primary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.open_in_new_rounded, size: 16, color: primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  final bool isDesktop;

  const _DateSeparator({required this.date, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final color = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          DateFormat('d MMMM yyyy', 'ru').format(date),
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  final ChatMessage message;
  final String chatId;
  final VoidCallback onResponse;
  final bool isDesktop;
  final void Function(String orderId)? onOrderTap;

  const _ApprovalCard({
    required this.message,
    required this.chatId,
    required this.onResponse,
    this.isDesktop = false,
    this.onOrderTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderId = message.orderId;
    final order = orderId != null && orderId.isNotEmpty
        ? ref.watch(orderByIdProvider(orderId))
        : null;
    final statusFromOrder = order?.status;
    final statusLabel = statusFromOrder != null
        ? statusFromOrder.label
        : (message.approvalStatus == ApprovalStatus.approved
            ? 'Согласовано'
            : message.approvalStatus == ApprovalStatus.rejected
                ? 'Отклонено'
                : 'Ожидает ответа');
    final statusColor = statusFromOrder != null
        ? statusFromOrder.color
        : (message.approvalStatus == ApprovalStatus.approved
            ? (isDesktop ? AppColorsDesktop.success : AppColors.success)
            : message.approvalStatus == ApprovalStatus.rejected
                ? (isDesktop ? AppColorsDesktop.error : AppColors.error)
                : (isDesktop ? AppColorsDesktop.statusPending : AppColors.statusPending));
    final editedItems = message.editedApprovalItems ?? [];
    final newItems = message.newApprovalItems ?? [];
    final legacyItems = message.approvalItems ?? [];
    final orderDisplay = order != null ? order.displayNumber : '';
    final hasOrderLink = orderId != null && orderId.isNotEmpty;
    final cardBg = isDesktop ? AppColorsDesktop.surface : AppColors.cardBg;
    final borderColor = isDesktop ? AppColorsDesktop.border : AppColors.border;
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final textTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final primary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    final sectionBg = isDesktop ? AppColorsDesktop.nestedBg : AppColors.nestedBg;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: isDesktop ? 440 : MediaQuery.sizeOf(context).width * 0.85),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Шапка: статус по центру, ниже — текст о согласовании (номер заказа — в теле карточки).
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.06),
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Запрос на согласование отправлен',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Клиент увидит предложение и сможет подтвердить или выбрать другое время',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textTertiary, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasOrderLink) ...[
                        InkWell(
                          onTap: onOrderTap != null ? () => onOrderTap!(orderId) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 18, color: primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    orderDisplay.isNotEmpty ? 'Заказ $orderDisplay' : 'Открыть заказ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: primary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.open_in_new_rounded, size: 14, color: primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (order != null && order.plannedStartTime != null && order.plannedEndTime != null) ...[
                        Text(
                          'Время: с ${formatTime(order.plannedStartTime!)} до ${formatTime(order.plannedEndTime!)}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 10),
                      ] else if (message.proposedDateTime != null) ...[
                        Text(
                          'Предложенное время: ${formatDateTime(message.proposedDateTime!)}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Блок «Состав заказа»
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sectionBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Состав заказа',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if ((message.originalApprovalItems ?? []).isNotEmpty) ...[
                              Text('Изначально согласовано:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textTertiary)),
                              const SizedBox(height: 4),
                              ...(message.originalApprovalItems!).map((i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(i.name, style: TextStyle(fontSize: 13, color: textPrimary))),
                                        Text('${formatMoney(i.priceKopecks)} • ${formatDurationMinutes(i.estimatedMinutes)}', style: TextStyle(fontSize: 12, color: textSecondary)),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                            ],
                            if (editedItems.isNotEmpty) ...[
                              Text('Скорректированные:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textTertiary)),
                              const SizedBox(height: 4),
                              ...editedItems.map((i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(i.name, style: TextStyle(fontSize: 13, color: textPrimary))),
                                        Text('${formatMoney(i.priceKopecks)} • ${formatDurationMinutes(i.estimatedMinutes)}', style: TextStyle(fontSize: 12, color: primary)),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                            ],
                            if (newItems.isNotEmpty) ...[
                              Text('Добавленные:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textTertiary)),
                              const SizedBox(height: 4),
                              ...newItems.map((i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(i.name, style: TextStyle(fontSize: 13, color: textPrimary))),
                                        Text('${formatMoney(i.priceKopecks)} • ${formatDurationMinutes(i.estimatedMinutes)}', style: TextStyle(fontSize: 12, color: primary)),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                            ],
                            if (editedItems.isEmpty && newItems.isEmpty && legacyItems.isNotEmpty) ...[
                              ...legacyItems.map((i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(i.name, style: TextStyle(fontSize: 13, color: textPrimary))),
                                        Text(formatMoney(i.priceKopecks), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ApprovalCostRow('Было:', formatMoney(message.totalsBeforePriceKopecks ?? (message.originalApprovalItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks)), textSecondary, textPrimary),
                      if (newItems.isNotEmpty || editedItems.isNotEmpty)
                        _ApprovalCostRow(
                          'Доп. услуги:',
                          formatMoney((message.totalsAfterPriceKopecks ?? message.approvalTotalKopecks) - (message.totalsBeforePriceKopecks ?? (message.originalApprovalItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks))),
                          textSecondary,
                          textPrimary,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Итого:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                          Text(
                            formatMoney(message.totalsAfterPriceKopecks ?? message.approvalTotalKopecks),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Время отправки запроса — правый нижний угол
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Отправлено ${DateFormat('dd.MM в HH:mm').format(message.at)}',
                          style: TextStyle(fontSize: 11, color: textTertiary),
                        ),
                      ),
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

class _ApprovalCostRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;

  const _ApprovalCostRow(this.label, this.value, [this.labelColor, this.valueColor]);

  @override
  Widget build(BuildContext context) {
    final lColor = labelColor ?? AppColors.textSecondary;
    final vColor = valueColor ?? AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: lColor)),
          Text(value, style: TextStyle(fontSize: 13, color: vColor)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
