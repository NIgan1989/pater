import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';

/// Экран аналитики для владельца
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  final BookingService _bookingService = BookingService();
  
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalIncome = 0;
  double _occupancyRate = 0;
  List<Property> _properties = [];
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// Загружает данные для аналитики
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Получаем свойства владельца
      final properties = await _propertyService.getOwnerProperties();
      
      // Загружаем базовую статистику (в реальном приложении могут быть отдельные API)
      int totalBookings = 0;
      double totalIncome = 0;
      
      // В реальном приложении это делалось бы на бэкенде, 
      // здесь просто имитируем данные
      for (final property in properties) {
        final bookings = await _bookingService.getPropertyBookings(property.id);
        totalBookings += bookings.length;
        
        // Суммируем доход от завершенных и подтвержденных бронирований
        totalIncome += bookings
            .where((b) => b.status == BookingStatus.completed || b.status == BookingStatus.confirmed)
            .fold(0.0, (prev, b) => prev + b.totalPrice);
      }
      
      // Расчет заполняемости (упрощенно)
      final double occupancyRate = properties.isNotEmpty 
          ? (totalBookings / (properties.length * 30)) * 100 // 30 дней условно на объект
          : 0;
      
      setState(() {
        _properties = properties;
        _totalBookings = totalBookings;
        _totalIncome = totalIncome;
        _occupancyRate = occupancyRate;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: CustomAppBar(
        title: 'Аналитика и статистика',
        backgroundColor: theme.colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Обзор'),
            Tab(text: 'Доход'),
            Tab(text: 'Объекты'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          indicatorColor: theme.colorScheme.primary,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme),
                _buildIncomeTab(theme),
                _buildPropertiesTab(theme),
              ],
            ),
    );
  }
  
  /// Строит вкладку с общим обзором
  Widget _buildOverviewTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Информационные карточки
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  theme,
                  title: 'Всего бронирований',
                  value: _totalBookings.toString(),
                  icon: Icons.calendar_today,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppConstants.paddingM),
              Expanded(
                child: _buildInfoCard(
                  theme,
                  title: 'Общий доход',
                  value: '${_totalIncome.toStringAsFixed(0)} ₽',
                  icon: Icons.payments,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingM),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  theme,
                  title: 'Заполняемость',
                  value: '${_occupancyRate.toStringAsFixed(1)}%',
                  icon: Icons.pie_chart,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: AppConstants.paddingM),
              Expanded(
                child: _buildInfoCard(
                  theme,
                  title: 'Активных объектов',
                  value: _properties.length.toString(),
                  icon: Icons.home,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          
          // График бронирования по месяцам
          const SizedBox(height: AppConstants.paddingXL),
          Text(
            'Бронирования по месяцам',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppConstants.paddingM),
          Container(
            height: 250,
            padding: const EdgeInsets.all(AppConstants.paddingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildBookingsChart(theme),
          ),
          
          // График дохода по месяцам
          const SizedBox(height: AppConstants.paddingXL),
          Text(
            'Доход по месяцам',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppConstants.paddingM),
          Container(
            height: 250,
            padding: const EdgeInsets.all(AppConstants.paddingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildIncomeChart(theme),
          ),
          
          // Топ объекты по заполняемости
          const SizedBox(height: AppConstants.paddingXL),
          Text(
            'Топ объекты по заполняемости',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppConstants.paddingM),
          Column(
            children: _properties.isEmpty
                ? [
                    SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'У вас пока нет объектов',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ]
                : _properties.take(3).map((property) {
                    // В реальном приложении здесь должны быть настоящие данные
                    final occupancy = (60 + _properties.indexOf(property) * 10).toDouble();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
                      padding: const EdgeInsets.all(AppConstants.paddingM),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                                  image: property.imageUrls.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(property.imageUrls.first),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                ),
                                child: property.imageUrls.isEmpty
                                    ? const Icon(Icons.home_outlined)
                                    : null,
                              ),
                              const SizedBox(width: AppConstants.paddingM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      property.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppConstants.fontSizeBody,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      property.address,
                                      style: TextStyle(
                                        fontSize: AppConstants.fontSizeSmall,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.paddingS),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppConstants.radiusS),
                            child: LinearProgressIndicator(
                              value: occupancy / 100,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              color: theme.colorScheme.primary,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Заполняемость',
                                style: TextStyle(
                                  fontSize: AppConstants.fontSizeSmall,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              Text(
                                '${occupancy.toInt()}%',
                                style: const TextStyle(
                                  fontSize: AppConstants.fontSizeSmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// Строит вкладку с доходом
  Widget _buildIncomeTab(ThemeData theme) {
    // Заглушка с данными
    final monthlyData = [
      {'month': 'Янв', 'income': 45000.0},
      {'month': 'Фев', 'income': 52000.0},
      {'month': 'Мар', 'income': 48000.0},
      {'month': 'Апр', 'income': 60000.0},
      {'month': 'Май', 'income': 75000.0},
      {'month': 'Июн', 'income': 90000.0},
      {'month': 'Июл', 'income': 105000.0},
      {'month': 'Авг', 'income': 120000.0},
      {'month': 'Сен', 'income': 95000.0},
      {'month': 'Окт', 'income': 85000.0},
      {'month': 'Ноя', 'income': 78000.0},
      {'month': 'Дек', 'income': 110000.0},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Доход за текущий год',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppConstants.paddingM),
          Container(
            height: 300,
            padding: const EdgeInsets.all(AppConstants.paddingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildYearlyIncomeChart(theme, monthlyData),
          ),
          
          const SizedBox(height: AppConstants.paddingXL),
          Text(
            'Доход по месяцам',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppConstants.paddingM),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthlyData.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final data = monthlyData[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(data['month'] as String),
                trailing: Text(
                  '${(data['income'] as double).toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppConstants.fontSizeBody,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  /// Строит вкладку с объектами
  Widget _buildPropertiesTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика по объектам',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppConstants.paddingM),
          if (_properties.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'У вас пока нет объектов',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final property = _properties[index];
                
                // Заглушка для статистики
                final bookings = (10 + index * 2).toInt();
                final income = (50000.0 + index * 10000.0);
                final occupancy = (65.0 + index * 5.0).clamp(0.0, 100.0);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppConstants.radiusS),
                                image: property.imageUrls.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(property.imageUrls.first),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                              ),
                              child: property.imageUrls.isEmpty
                                  ? const Icon(Icons.home_outlined)
                                  : null,
                            ),
                            const SizedBox(width: AppConstants.paddingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    property.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppConstants.fontSizeBody,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    property.address,
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeSmall,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.paddingM),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPropertyStat(
                                theme,
                                icon: Icons.calendar_today,
                                value: bookings.toString(),
                                label: 'Бронирований',
                              ),
                            ),
                            Expanded(
                              child: _buildPropertyStat(
                                theme,
                                icon: Icons.payments,
                                value: '${income.toStringAsFixed(0)} ₽',
                                label: 'Доход',
                              ),
                            ),
                            Expanded(
                              child: _buildPropertyStat(
                                theme,
                                icon: Icons.pie_chart,
                                value: '${occupancy.toStringAsFixed(1)}%',
                                label: 'Заполняемость',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.paddingM),
                        OutlinedButton(
                          onPressed: () {
                            // Подробная статистика
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                          ),
                          child: const Text('Подробная статистика'),
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
  
  /// Строит информационную карточку
  Widget _buildInfoCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingS),
          Text(
            title,
            style: TextStyle(
              fontSize: AppConstants.fontSizeSecondary,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Строит статистику объекта
  Widget _buildPropertyStat(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConstants.fontSizeBody,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: AppConstants.fontSizeSmall,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  /// Строит график бронирований
  Widget _buildBookingsChart(ThemeData theme) {
    // Заглушка с данными
    final barGroups = [
      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 5)]), // Янв
      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 6)]), // Фев
      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 8)]), // Мар
      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 10)]), // Апр
      BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 12)]), // Май
      BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 16)]), // Июн
      BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 20)]), // Июл
      BarChartGroupData(x: 7, barRods: [BarChartRodData(toY: 18)]), // Авг
      BarChartGroupData(x: 8, barRods: [BarChartRodData(toY: 14)]), // Сен
      BarChartGroupData(x: 9, barRods: [BarChartRodData(toY: 12)]), // Окт
      BarChartGroupData(x: 10, barRods: [BarChartRodData(toY: 8)]), // Ноя
      BarChartGroupData(x: 11, barRods: [BarChartRodData(toY: 10)]), // Дек
    ];
    
    return BarChart(
      BarChartData(
        barGroups: barGroups.map((group) {
          return BarChartGroupData(
            x: group.x,
            barRods: [
              BarChartRodData(
                toY: group.barRods.first.toY,
                color: theme.colorScheme.primary,
                width: 15,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    months[value.toInt()],
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
  
  /// Строит график дохода
  Widget _buildIncomeChart(ThemeData theme) {
    // Заглушка с данными
    final spots = [
      const FlSpot(0, 45000), // Янв
      const FlSpot(1, 52000), // Фев
      const FlSpot(2, 48000), // Мар
      const FlSpot(3, 60000), // Апр
      const FlSpot(4, 75000), // Май
      const FlSpot(5, 90000), // Июн
      const FlSpot(6, 105000), // Июл
      const FlSpot(7, 120000), // Авг
      const FlSpot(8, 95000), // Сен
      const FlSpot(9, 85000), // Окт
      const FlSpot(10, 78000), // Ноя
      const FlSpot(11, 110000), // Дек
    ];
    
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    months[value.toInt()],
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
  
  /// Строит годовой график дохода
  Widget _buildYearlyIncomeChart(ThemeData theme, List<Map<String, dynamic>> data) {
    // Создаем список точек на графике
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value['income'] as double);
    }).toList();
    
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.green,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final month = data[barSpot.x.toInt()]['month'] as String;
                final income = data[barSpot.x.toInt()]['income'] as double;
                
                return LineTooltipItem(
                  '$month: ${income.toStringAsFixed(0)} ₽',
                  TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data[index]['month'] as String,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: 25000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }
} 