import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/payment_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/payment_receipt.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/core/di/service_locator.dart';

/// Модель транзакции для отображения в истории
class Transaction {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String? relatedBookingId;
  final String? relatedPropertyId;
  final String? receiptId;

  const Transaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    this.relatedBookingId,
    this.relatedPropertyId,
    this.receiptId,
  });
}

/// Тип транзакции
enum TransactionType {
  /// Приход (оплата бронирования)
  income,

  /// Расход (комиссия платформы, плата за услуги)
  expense,

  /// Вывод средств
  withdrawal,
}

/// Экран финансов профиля
class FinancesScreen extends StatefulWidget {
  const FinancesScreen({super.key});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen>
    with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final PropertyService _propertyService = PropertyService();
  late final AuthService _authService;
  final PaymentService _paymentService = PaymentService();

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  // Данные пользователя
  User? _user;

  // Финансовая информация
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalWithdrawals = 0.0;

  // Список транзакций
  List<Transaction> _transactions = [];

  // Список чеков
  List<PaymentReceipt> _receipts = [];

  // Форматтер для дат
  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  // Форматтер для валюты
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'ru_RU',
    symbol: '₸',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _authService = getIt<AuthService>();
    _user = _authService.currentUser;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Загружает финансовые данные пользователя
  Future<void> _loadData() async {
    if (_user == null) {
      setState(() {
        _errorMessage = 'Пользователь не авторизован';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Получение бронирований для отображения истории заказов
      final bookings = await _bookingService.getUserBookings(_user!.id);

      // Получаем информацию об объектах
      final properties = await _propertyService.getAllProperties();

      // Получаем чеки оплаты
      final receipts = await _paymentService.getUserReceipts(_user!.id);

      // Генерируем транзакции на основе бронирований и чеков
      final generatedTransactions = _generateTransactions(
        bookings,
        properties,
        receipts,
      );

      // Рассчитываем финансовые показатели
      _calculateFinancialMetrics(generatedTransactions);

      if (mounted) {
        setState(() {
          _transactions = generatedTransactions;
          _receipts = receipts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке финансовой информации: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при загрузке данных: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Генерирует список транзакций из бронирований
  List<Transaction> _generateTransactions(
    List<Booking> bookings,
    List<Property> properties,
    List<PaymentReceipt> receipts,
  ) {
    final List<Transaction> transactions = [];

    // Для каждого бронирования создаем транзакцию дохода
    for (final booking in bookings) {
      // Находим связанный объект
      final property = properties.firstWhere(
        (property) => property.id == booking.propertyId,
        orElse:
            () => Property(
              id: 'unknown',
              title: 'Неизвестный объект',
              description: '',
              ownerId: '',
              type: PropertyType.apartment,
              status: PropertyStatus.available,
              imageUrls: [],
              address: '',
              city: '',
              country: '',
              latitude: 0,
              longitude: 0,
              pricePerNight: 0,
              pricePerHour: 0,
              area: 0,
              rooms: 0,
              bathrooms: 0,
              maxGuests: 0,
              hasWifi: false,
              hasParking: false,
              hasAirConditioning: false,
              hasKitchen: false,
              hasTV: false,
              hasWashingMachine: false,
              petFriendly: false,
              checkInTime: '',
              checkOutTime: '',
              rating: 0,
              reviewsCount: 0,
              isFeatured: false,
              isOnModeration: false,
              isActive: false,
              views: 0,
            ),
      );

      // Пропускаем отмененные бронирования
      if (booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.cancelledByClient ||
          booking.status == BookingStatus.rejectedByOwner) {
        continue;
      }

      // Ищем чек для этого бронирования
      String? receiptId;
      for (final receipt in receipts) {
        if (receipt.bookingId == booking.id) {
          receiptId = receipt.id;
          break;
        }
      }

      // Создаем транзакцию прихода
      transactions.add(
        Transaction(
          id: 'income_${booking.id}',
          title: 'Оплата бронирования',
          description:
              'Объект: ${property.title}, ${_dateFormatter.format(booking.checkInDate)} - ${_dateFormatter.format(booking.checkOutDate)}',
          amount: booking.totalPrice,
          date: booking.createdAt,
          type: TransactionType.income,
          relatedBookingId: booking.id,
          relatedPropertyId: booking.propertyId,
          receiptId: receiptId,
        ),
      );

      // Создаем транзакцию комиссии платформы (условно 10%)
      final commissionAmount = booking.totalPrice * 0.1;
      transactions.add(
        Transaction(
          id: 'fee_${booking.id}',
          title: 'Комиссия платформы',
          description: 'Комиссия за бронирование объекта "${property.title}"',
          amount: commissionAmount,
          date: booking.createdAt,
          type: TransactionType.expense,
          relatedBookingId: booking.id,
          relatedPropertyId: booking.propertyId,
        ),
      );
    }

    // Добавляем имитацию вывода средств
    if (transactions.isNotEmpty) {
      final totalIncome = transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);

      final totalExpense = transactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, t) => sum + t.amount);

      final availableForWithdrawal = totalIncome - totalExpense;

      // Если есть что выводить, добавляем одну транзакцию вывода средств
      if (availableForWithdrawal > 0) {
        final withdrawalAmount =
            availableForWithdrawal *
            0.6; // Условно пользователь вывел 60% доступных средств

        transactions.add(
          Transaction(
            id: 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Вывод средств',
            description: 'Вывод на банковский счет',
            amount: withdrawalAmount,
            date: DateTime.now().subtract(const Duration(days: 7)),
            type: TransactionType.withdrawal,
          ),
        );
      }
    }

    // Сортируем транзакции по дате (от новых к старым)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions;
  }

  /// Рассчитывает финансовые показатели
  void _calculateFinancialMetrics(List<Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;
    double totalWithdrawals = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        totalExpenses += transaction.amount;
      } else if (transaction.type == TransactionType.withdrawal) {
        totalWithdrawals += transaction.amount;
      }
    }

    _totalIncome = totalIncome;
    _totalWithdrawals = totalWithdrawals;
    _balance = totalIncome - totalExpenses - totalWithdrawals;
  }

  /// Показывает чек оплаты
  Future<void> _showReceipt(String receiptId) async {
    // Найдем чек по ID
    final receipt = _receipts.firstWhere(
      (r) => r.id == receiptId,
      orElse:
          () => PaymentReceipt(
            id: '',
            transactionId: '',
            bookingId: '',
            userId: '',
            amount: 0,
            paymentMethod: '',
            createdAt: DateTime.now(),
            items: [],
          ),
    );

    // Проверяем, найден ли действительный чек
    if (receipt.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Чек не найден'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Получаем форматтер для дат и денег
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

    // Определяем название метода оплаты для отображения
    final paymentMethodName = _getPaymentMethodName(receipt.paymentMethod);

    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Чек оплаты',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildReceiptRow('Номер чека:', receipt.id),
                  _buildReceiptRow(
                    'Дата и время:',
                    dateFormat.format(receipt.createdAt),
                  ),
                  _buildReceiptRow('Способ оплаты:', paymentMethodName),
                  _buildReceiptRow('ID бронирования:', receipt.bookingId),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Детали оплаты',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...receipt.items.map(
                    (item) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          item['description'] as String,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _currencyFormatter.format(item['amount']),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Итого:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _currencyFormatter.format(receipt.amount),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReceipt(receipt),
                      icon: const Icon(Icons.share),
                      label: const Text('Поделиться чеком'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Создает строку данных чека
  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Получает название метода оплаты из кода
  String _getPaymentMethodName(String methodCode) {
    switch (methodCode) {
      case 'card':
        return 'Банковская карта';
      case 'kaspi':
        return 'Kaspi Bank';
      case 'halyk':
        return 'Халык Банк';
      case 'transfer':
        return 'Банковский перевод';
      default:
        return methodCode;
    }
  }

  /// Делится чеком (в реальном приложении здесь будет экспорт PDF)
  void _shareReceipt(PaymentReceipt receipt) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Функция "Поделиться чеком" будет доступна в следующей версии',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Финансы')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Text(
                  'Ошибка: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFinancialSummary(),
                      _buildChart(),
                      _buildTransactionsTabs(),
                    ],
                  ),
                ),
              ),
    );
  }

  /// Строит блок с финансовой сводкой
  Widget _buildFinancialSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Финансовая сводка',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFinancialInfoCard(
                  title: 'Баланс',
                  value: _balance,
                  icon: Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialInfoCard(
                  title: 'Доход',
                  value: _totalIncome,
                  icon: Icons.arrow_upward,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFinancialInfoCard(
                  title: 'Расходы',
                  value: _totalIncome - _balance - _totalWithdrawals,
                  icon: Icons.arrow_downward,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialInfoCard(
                  title: 'Выведено',
                  value: _totalWithdrawals,
                  icon: Icons.money_off,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Строит карточку с финансовой информацией
  Widget _buildFinancialInfoCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormatter.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Строит вкладки для отображения транзакций
  Widget _buildTransactionsTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha(153),
              tabs: const [
                Tab(text: 'Все'),
                Tab(text: 'Доходы'),
                Tab(text: 'Расходы'),
              ],
            ),
          ),
          SizedBox(
            height: 400, // Фиксированная высота для списка транзакций
            child: TabBarView(
              children: [
                _buildTransactionsList(_transactions),
                _buildTransactionsList(
                  _transactions
                      .where((t) => t.type == TransactionType.income)
                      .toList(),
                ),
                _buildTransactionsList(
                  _transactions
                      .where(
                        (t) =>
                            t.type == TransactionType.expense ||
                            t.type == TransactionType.withdrawal,
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Строит список транзакций
  Widget _buildTransactionsList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'Нет транзакций для отображения',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];

        return _buildTransactionCard(transaction);
      },
    );
  }

  /// Строит карточку транзакции с кнопкой просмотра чека
  Widget _buildTransactionCard(Transaction transaction) {
    final isIncome = transaction.type == TransactionType.income;
    final isWithdrawal = transaction.type == TransactionType.withdrawal;

    final icon =
        isIncome
            ? Icons.arrow_upward
            : isWithdrawal
            ? Icons.money_off
            : Icons.arrow_downward;

    final color =
        isIncome
            ? Colors.green
            : isWithdrawal
            ? Colors.orange
            : Colors.red;

    final signPrefix = isIncome ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(icon, color: color),
            ),
            title: Text(
              transaction.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.description),
                Text(
                  _dateFormatter.format(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(153),
                  ),
                ),
              ],
            ),
            trailing: Text(
              '$signPrefix${_currencyFormatter.format(transaction.amount)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          // Если есть чек, показываем кнопку для его просмотра
          if (transaction.receiptId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showReceipt(transaction.receiptId!),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Просмотреть чек'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(40, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Строит график доходов/расходов
  Widget _buildChart() {
    final chartData = _prepareChartData();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Динамика доходов и расходов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartData.maxValue * 1.2,
                minY: 0,
                barGroups: chartData.barGroups,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: _getBottomTitles()),
                  leftTitles: AxisTitles(sideTitles: _getLeftTitles()),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: chartData.maxValue / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 50),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: Colors.green.withValues(alpha: 180),
                label: 'Доходы',
              ),
              const SizedBox(width: 30),
              _buildLegendItem(
                color: Colors.red.withValues(alpha: 180),
                label: 'Расходы',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Строит элемент легенды для графика
  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Подготавливает данные для графика
  _ChartData _prepareChartData() {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    // Группируем транзакции по месяцам
    final Map<String, Map<TransactionType, double>> monthlyData = {};

    for (var i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MM.yyyy').format(month);
      monthlyData[monthKey] = {
        TransactionType.income: 0,
        TransactionType.expense: 0,
        TransactionType.withdrawal: 0,
      };
    }

    for (final transaction in _transactions) {
      if (transaction.date.isAfter(sixMonthsAgo)) {
        final monthKey = DateFormat(
          'MM.yyyy',
        ).format(DateTime(transaction.date.year, transaction.date.month, 1));

        if (monthlyData.containsKey(monthKey)) {
          if (transaction.type == TransactionType.income) {
            monthlyData[monthKey]![TransactionType.income] =
                (monthlyData[monthKey]![TransactionType.income] ?? 0) +
                transaction.amount;
          } else if (transaction.type == TransactionType.expense) {
            monthlyData[monthKey]![TransactionType.expense] =
                (monthlyData[monthKey]![TransactionType.expense] ?? 0) +
                transaction.amount;
          } else if (transaction.type == TransactionType.withdrawal) {
            monthlyData[monthKey]![TransactionType.withdrawal] =
                (monthlyData[monthKey]![TransactionType.withdrawal] ?? 0) +
                transaction.amount;
          }
        }
      }
    }

    // Создаем список месяцев в правильном порядке
    final monthsInOrder = <String>[];
    final monthNames = <String>[];

    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MM.yyyy').format(month);
      monthsInOrder.add(monthKey);
      monthNames.add(DateFormat('MMM').format(month));
    }

    // Создаем группы столбцов для графика
    final barGroups = <BarChartGroupData>[];
    var maxValue = 0.0;

    for (var i = 0; i < monthsInOrder.length; i++) {
      final monthKey = monthsInOrder[i];
      final monthData = monthlyData[monthKey]!;

      final incomeValue = monthData[TransactionType.income] ?? 0.0;
      final expenseValue = monthData[TransactionType.expense] ?? 0.0;

      maxValue = [
        maxValue,
        incomeValue,
        expenseValue,
      ].reduce((a, b) => a > b ? a : b);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: incomeValue,
              color: Colors.green.withValues(alpha: 180),
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: expenseValue,
              color: Colors.red.withValues(alpha: 180),
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return _ChartData(
      barGroups: barGroups,
      months: monthNames,
      maxValue: maxValue,
    );
  }

  Widget getTitlesWidget(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    final chartData = _prepareChartData();
    String text = '';
    if (value.toInt() >= 0 && value.toInt() < chartData.months.length) {
      text = chartData.months[value.toInt()];
    }

    return SideTitleWidget(meta: meta, child: Text(text, style: style));
  }

  SideTitles _getBottomTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: getTitlesWidget,
    );
  }

  Widget getLeftTitlesWidget(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    return SideTitleWidget(
      meta: meta,
      child: Text('${value.toInt()} ₽', style: style),
    );
  }

  SideTitles _getLeftTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 50,
      interval: 5000,
      getTitlesWidget: getLeftTitlesWidget,
    );
  }
}

/// Данные для графика
class _ChartData {
  final List<BarChartGroupData> barGroups;
  final List<String> months;
  final double maxValue;

  const _ChartData({
    required this.barGroups,
    required this.months,
    required this.maxValue,
  });
}
