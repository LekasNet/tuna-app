import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/uikit/widgets/simple_select_field.dart';
import '../core/tunnels/tunnel_models.dart';
import '../di/tabs/tabs_controller.dart';
import '../di/tunnels/tunnels_controller.dart';
import '../utils/helpers.dart';
import 'widgets/tunnel_card.dart';
import 'widgets/tunnel_presenters.dart';

enum _FailuresPeriod { session, h1, h12, day, week, month }

class DashboardScreen extends StatefulWidget {
  final TabsController tabsController;
  final TunnelsController tunnelsController;

  const DashboardScreen({
    super.key,
    required this.tabsController,
    required this.tunnelsController,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _selectedFailuresTunnelKey =
      'dashboard_selected_failures_tunnel_id';
  static const String _allTunnelsOption = '__all__';
  static const List<Color> _linePalette = [
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFD35400),
    Color(0xFF2E86C1),
  ];

  final DateTime _sessionStartedAt = DateTime.now();
  String? _selectedFailuresTunnelId;
  bool _selectionLoaded = false;
  _FailuresPeriod _selectedFailuresPeriod = _FailuresPeriod.session;

  @override
  void initState() {
    super.initState();
    _loadSavedFailuresTunnelSelection();
  }

  Future<void> _loadSavedFailuresTunnelSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_selectedFailuresTunnelKey);
    if (!mounted) return;
    setState(() {
      _selectedFailuresTunnelId = savedId;
      _selectionLoaded = true;
    });
  }

  Future<void> _saveFailuresTunnelSelection(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFailuresTunnelKey, id);
  }

  void _selectFailuresTunnel(String id) {
    if (_selectedFailuresTunnelId == id) return;
    setState(() => _selectedFailuresTunnelId = id);
    _saveFailuresTunnelSelection(id);
  }

  void _selectFailuresPeriod(_FailuresPeriod period) {
    if (_selectedFailuresPeriod == period) return;
    setState(() => _selectedFailuresPeriod = period);
  }

  Future<void> _toggleTunnel(SavedTunnel tunnel) async {
    final controller = widget.tunnelsController;
    final isRunning = controller.isRunning(tunnel.id);

    if (isRunning) {
      await controller.stopTunnel(tunnel);
      return;
    }

    try {
      await controller.startTunnel(tunnel);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось запустить тоннель')),
      );
    }
  }

  Future<void> _openPublicUrl(String url) async {
    try {
      await launchWeb(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось открыть URL')));
    }
  }

  void _openTunnelDetails(SavedTunnel tunnel) {
    widget.tunnelsController.selectTunnel(tunnel.id);
    widget.tabsController.selectTab(AppTab.tunnels);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final date = dateTime.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  _PeriodConfig _periodConfig(_FailuresPeriod period, DateTime now) {
    switch (period) {
      case _FailuresPeriod.session:
        final duration = now.difference(_sessionStartedAt);
        final safeDuration = duration <= Duration.zero
            ? const Duration(minutes: 10)
            : duration;
        final bucketCount = math.max(
          12,
          math.min(60, safeDuration.inMinutes ~/ 3),
        );
        return _PeriodConfig(
          start: _sessionStartedAt,
          end: now,
          bucketCount: bucketCount,
          label: 'Session',
        );
      case _FailuresPeriod.h1:
        return _PeriodConfig(
          start: now.subtract(const Duration(hours: 1)),
          end: now,
          bucketCount: 60,
          label: '1h',
        );
      case _FailuresPeriod.h12:
        return _PeriodConfig(
          start: now.subtract(const Duration(hours: 12)),
          end: now,
          bucketCount: 72,
          label: '12h',
        );
      case _FailuresPeriod.day:
        return _PeriodConfig(
          start: now.subtract(const Duration(days: 1)),
          end: now,
          bucketCount: 48,
          label: 'Day',
        );
      case _FailuresPeriod.week:
        return _PeriodConfig(
          start: now.subtract(const Duration(days: 7)),
          end: now,
          bucketCount: 56,
          label: 'Week',
        );
      case _FailuresPeriod.month:
        return _PeriodConfig(
          start: now.subtract(const Duration(days: 30)),
          end: now,
          bucketCount: 60,
          label: 'Month',
        );
    }
  }

  _FailureSeries _buildFailureSeriesByTime({
    required List<DateTime> eventsUtc,
    required _PeriodConfig config,
  }) {
    final points = List<int>.filled(config.bucketCount, 0);
    final span = config.end.difference(config.start);
    final spanMicros = span.inMicroseconds;
    if (spanMicros <= 0) {
      return _FailureSeries(
        points: points,
        failureCount: 0,
        attemptsCount: config.bucketCount,
        start: config.start,
        end: config.end,
        label: config.label,
      );
    }

    for (final eventUtc in eventsUtc) {
      final event = eventUtc.toLocal();
      if (event.isBefore(config.start) || event.isAfter(config.end)) continue;

      final fromStart = event.difference(config.start).inMicroseconds;
      var index = ((fromStart / spanMicros) * config.bucketCount).floor();
      if (index < 0) index = 0;
      if (index >= config.bucketCount) index = config.bucketCount - 1;
      points[index] += 1;
    }

    final failuresCount = points.fold<int>(0, (sum, item) => sum + item);
    return _FailureSeries(
      points: points,
      failureCount: failuresCount,
      attemptsCount: config.bucketCount,
      start: config.start,
      end: config.end,
      label: config.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tunnelsController,
      builder: (context, _) {
        final controller = widget.tunnelsController;
        if (!controller.initialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final tunnels = controller.tunnels;
        final totalCount = tunnels.length;
        final activeCount = tunnels
            .where(
              (t) =>
                  t.status == TunnelStatus.active ||
                  t.status == TunnelStatus.starting,
            )
            .length;
        final failedCount = tunnels
            .where((t) => t.status == TunnelStatus.failed)
            .length;
        final stableCount = totalCount - failedCount;
        final remoteActiveCount = controller.remoteActiveCount;
        final knownRunningTotal = activeCount + remoteActiveCount;

        final activeRatio = totalCount == 0 ? 0.0 : activeCount / totalCount;
        final stableRatio = totalCount == 0 ? 0.0 : stableCount / totalCount;
        final localVsRemoteRatio = knownRunningTotal == 0
            ? 0.0
            : activeCount / knownRunningTotal;

        final selectedFailuresTunnel = tunnels
            .where((t) => t.id == _selectedFailuresTunnelId)
            .toList(growable: false);

        SavedTunnel? failuresTunnel;
        if (selectedFailuresTunnel.isNotEmpty) {
          failuresTunnel = selectedFailuresTunnel.first;
        } else if (tunnels.isNotEmpty) {
          failuresTunnel = tunnels.first;
          if (_selectionLoaded &&
              _selectedFailuresTunnelId != failuresTunnel.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _selectFailuresTunnel(failuresTunnel!.id);
            });
          }
        }

        final now = DateTime.now();
        final config = _periodConfig(_selectedFailuresPeriod, now);
        final failureEvents = failuresTunnel == null
            ? const <DateTime>[]
            : controller.failureEventsFor(failuresTunnel.id);
        final failureSeries = _buildFailureSeriesByTime(
          eventsUtc: failureEvents,
          config: config,
        );

        final recentStarted =
            tunnels
                .where((t) => t.lastStartedAt != null)
                .toList(growable: false)
              ..sort((a, b) => b.lastStartedAt!.compareTo(a.lastStartedAt!));
        final latestTwo = recentStarted.take(2).toList(growable: false);

        final tunnelOptions = tunnels
            .map(
              (tunnel) => SimpleSelectOption<String>(
                value: tunnel.id,
                label: tunnel.name,
              ),
            )
            .toList(growable: false);

        final periodOptions = const <SimpleSelectOption<_FailuresPeriod>>[
          SimpleSelectOption(value: _FailuresPeriod.session, label: 'session'),
          SimpleSelectOption(value: _FailuresPeriod.h1, label: '1h'),
          SimpleSelectOption(value: _FailuresPeriod.h12, label: '12h'),
          SimpleSelectOption(value: _FailuresPeriod.day, label: 'day'),
          SimpleSelectOption(value: _FailuresPeriod.week, label: 'week'),
          SimpleSelectOption(value: _FailuresPeriod.month, label: 'month'),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final ringSectionHeight = height < 560
                ? 130.0
                : (height < 680 ? 152.0 : 182.0);
            final failuresHeight = height < 560
                ? 140.0
                : (height < 680 ? 156.0 : 176.0);

            return Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _RingsAdaptiveSection(
                    height: ringSectionHeight,
                    activeRatio: activeRatio,
                    stableRatio: stableRatio,
                    localRemoteRatio: localVsRemoteRatio,
                    activeCount: activeCount,
                    totalCount: totalCount,
                    stableCount: stableCount,
                    knownRunningTotal: knownRunningTotal,
                    remoteActiveCount: remoteActiveCount,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: failuresHeight,
                    child: _FailuresTimelineCard(
                      selectedTunnelId: failuresTunnel?.id,
                      tunnelOptions: tunnelOptions,
                      period: _selectedFailuresPeriod,
                      periodOptions: periodOptions,
                      onTunnelChanged: _selectFailuresTunnel,
                      onPeriodChanged: _selectFailuresPeriod,
                      series: failureSeries,
                      tunnelName: failuresTunnel?.name,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '2 последних запуска',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: latestTwo.isEmpty
                                ? Center(
                                    child: Text(
                                      'Запуски пока не зафиксированы.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: latestTwo.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final tunnel = latestTwo[index];
                                      final isRunning = controller.isRunning(
                                        tunnel.id,
                                      );
                                      final forwarding = controller
                                          .forwardingFor(tunnel.id);
                                      final address =
                                          tunnel.ip != null &&
                                              tunnel.ip!.isNotEmpty
                                          ? '${tunnel.ip}:${tunnel.localPort}'
                                          : 'порт ${tunnel.localPort}';
                                      final subtitle =
                                          '${tunnelTypeLabel(tunnel.type)} • $address • ${tunnelStatusLabel(tunnel.status)}';

                                      return TunnelCard(
                                        title: tunnel.name,
                                        subtitle: subtitle,
                                        activityColor: tunnelStatusColor(
                                          context,
                                          tunnel.status,
                                        ),
                                        activityHint:
                                            'Статус: ${tunnelStatusLabel(tunnel.status)}',
                                        onTap: () => _openTunnelDetails(tunnel),
                                        rowCrossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        footer: Text(
                                          'Последний запуск: ${_formatDateTime(tunnel.lastStartedAt)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        actions: [
                                          IconButton(
                                            tooltip: isRunning
                                                ? 'Остановить'
                                                : 'Запустить',
                                            onPressed: () =>
                                                _toggleTunnel(tunnel),
                                            icon: Icon(
                                              isRunning
                                                  ? Icons.stop
                                                  : Icons.play_arrow,
                                            ),
                                          ),
                                          if (forwarding != null)
                                            IconButton(
                                              tooltip: 'Открыть URL',
                                              onPressed: () => _openPublicUrl(
                                                forwarding.publicUrl,
                                              ),
                                              icon: const Icon(
                                                Icons.open_in_new,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PeriodConfig {
  final DateTime start;
  final DateTime end;
  final int bucketCount;
  final String label;

  const _PeriodConfig({
    required this.start,
    required this.end,
    required this.bucketCount,
    required this.label,
  });
}

class _FailureSeries {
  final List<int> points;
  final int failureCount;
  final int attemptsCount;
  final DateTime start;
  final DateTime end;
  final String label;

  const _FailureSeries({
    required this.points,
    required this.failureCount,
    required this.attemptsCount,
    required this.start,
    required this.end,
    required this.label,
  });
}

class _RingsAdaptiveSection extends StatelessWidget {
  final double height;
  final double activeRatio;
  final double stableRatio;
  final double localRemoteRatio;
  final int activeCount;
  final int totalCount;
  final int stableCount;
  final int knownRunningTotal;
  final int remoteActiveCount;

  const _RingsAdaptiveSection({
    required this.height,
    required this.activeRatio,
    required this.stableRatio,
    required this.localRemoteRatio,
    required this.activeCount,
    required this.totalCount,
    required this.stableCount,
    required this.knownRunningTotal,
    required this.remoteActiveCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final available = constraints.maxWidth;

        final tileWithoutLegend = math.min(188.0, (available - 2 * gap) / 3);
        var showLegend = tileWithoutLegend < 170 && available >= 680;
        var legendWidth = showLegend ? math.max(150.0, available * 0.2) : 0.0;

        var tileSize = showLegend
            ? math.min(188.0, (available - legendWidth - 3 * gap) / 3)
            : tileWithoutLegend;

        if (tileSize < 112 && showLegend) {
          showLegend = false;
          legendWidth = 0;
          tileSize = math.min(188.0, (available - 2 * gap) / 3);
        }

        tileSize = math.min(tileSize, height);

        final tiles = [
          _RingSquareTile(
            size: tileSize,
            title: 'Active',
            ratio: activeRatio,
            centerValue: '$activeCount/$totalCount',
            color: Colors.green,
            tooltip: 'Активно: $activeCount из $totalCount локальных тоннелей',
          ),
          _RingSquareTile(
            size: tileSize,
            title: 'Stable',
            ratio: stableRatio,
            centerValue: '$stableCount/$totalCount',
            color: Colors.blue,
            tooltip: 'Без failed-статуса: $stableCount из $totalCount',
          ),
          _RingSquareTile(
            size: tileSize,
            title: 'Local/Remote',
            ratio: localRemoteRatio,
            centerValue: '$activeCount/$knownRunningTotal',
            color: Colors.orange,
            tooltip:
                'Локальные: $activeCount, удалённые активные: $remoteActiveCount',
          ),
        ];

        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                tiles[i],
              ],
              if (showLegend) ...[
                const SizedBox(width: gap),
                SizedBox(
                  width: legendWidth,
                  height: tileSize,
                  child: _RingsLegend(
                    activeCount: activeCount,
                    totalCount: totalCount,
                    stableCount: stableCount,
                    remoteActiveCount: remoteActiveCount,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RingSquareTile extends StatelessWidget {
  final double size;
  final String title;
  final double ratio;
  final String centerValue;
  final Color color;
  final String tooltip;

  const _RingSquareTile({
    required this.size,
    required this.title,
    required this.ratio,
    required this.centerValue,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _AnimatedRing(
                maxSize: size - 28,
                value: ratio.clamp(0.0, 1.0),
                color: color,
                centerTop: '${(ratio.clamp(0.0, 1.0) * 100).round()}%',
                centerBottom: centerValue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingsLegend extends StatelessWidget {
  final int activeCount;
  final int totalCount;
  final int stableCount;
  final int remoteActiveCount;

  const _RingsLegend({
    required this.activeCount,
    required this.totalCount,
    required this.stableCount,
    required this.remoteActiveCount,
  });

  Widget _item(
    BuildContext context, {
    required Color color,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _item(
            context,
            color: Colors.green,
            title: 'Active',
            value: '$activeCount/$totalCount',
          ),
          const SizedBox(height: 8),
          _item(
            context,
            color: Colors.blue,
            title: 'Stable',
            value: '$stableCount/$totalCount',
          ),
          const SizedBox(height: 8),
          _item(
            context,
            color: Colors.orange,
            title: 'Remote',
            value: '$remoteActiveCount',
          ),
        ],
      ),
    );
  }
}

class _AnimatedRing extends StatelessWidget {
  final double maxSize;
  final double value;
  final Color color;
  final String centerTop;
  final String centerBottom;

  const _AnimatedRing({
    required this.maxSize,
    required this.value,
    required this.color,
    required this.centerTop,
    required this.centerBottom,
  });

  @override
  Widget build(BuildContext context) {
    final size = math.max(64.0, math.min(132.0, maxSize));
    final trackColor = Theme.of(context).dividerColor.withValues(alpha: 0.35);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
        builder: (context, animatedValue, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  value: animatedValue,
                  color: color,
                  trackColor: trackColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerTop,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centerBottom,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _FailuresTimelineCard extends StatelessWidget {
  final String? selectedTunnelId;
  final List<SimpleSelectOption<String>> tunnelOptions;
  final _FailuresPeriod period;
  final List<SimpleSelectOption<_FailuresPeriod>> periodOptions;
  final ValueChanged<String> onTunnelChanged;
  final ValueChanged<_FailuresPeriod> onPeriodChanged;
  final _FailureSeries series;
  final String? tunnelName;

  const _FailuresTimelineCard({
    required this.selectedTunnelId,
    required this.tunnelOptions,
    required this.period,
    required this.periodOptions,
    required this.onTunnelChanged,
    required this.onPeriodChanged,
    required this.series,
    required this.tunnelName,
  });

  @override
  Widget build(BuildContext context) {
    final hasTunnels = tunnelOptions.isNotEmpty && selectedTunnelId != null;
    final tooltip = hasTunnels
        ? 'Сбои (${series.label}) для "$tunnelName": ${series.failureCount}'
        : 'Нет тоннелей для анализа сбоев';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Сбои по времени',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 30,
                            child: SimpleSelectField<_FailuresPeriod>(
                              value: period,
                              options: periodOptions,
                              onChanged: onPeriodChanged,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              itemExtent: 28,
                              itemSpacing: 4,
                              maxVisibleItems: 7,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (hasTunnels)
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: SimpleSelectField<String>(
                                  value: selectedTunnelId!,
                                  options: tunnelOptions,
                                  onChanged: onTunnelChanged,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  itemExtent: 28,
                                  itemSpacing: 4,
                                  maxVisibleItems: 7,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Text(
                      'Сбои по времени',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      height: 30,
                      child: SimpleSelectField<_FailuresPeriod>(
                        value: period,
                        options: periodOptions,
                        onChanged: onPeriodChanged,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        itemExtent: 28,
                        itemSpacing: 4,
                        maxVisibleItems: 7,
                      ),
                    ),
                    if (hasTunnels) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 260,
                        height: 30,
                        child: SimpleSelectField<String>(
                          value: selectedTunnelId!,
                          options: tunnelOptions,
                          onChanged: onTunnelChanged,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          itemExtent: 28,
                          itemSpacing: 4,
                          maxVisibleItems: 7,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hasTunnels
                  ? _FailuresLineChart(series: series)
                  : Center(
                      child: Text(
                        'Нет данных для графика',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailuresLineChart extends StatelessWidget {
  final _FailureSeries series;

  const _FailuresLineChart({required this.series});

  String _formatAxis(DateTime value) {
    final d = value.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    if (series.label == 'Week' || series.label == 'Month') {
      return '$day.$month';
    }
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FailuresLinePainter(
        points: series.points,
        lineColor: Theme.of(context).colorScheme.error,
        fillColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
        gridColor: Theme.of(context).dividerColor.withValues(alpha: 0.25),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatAxis(series.start),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            const Spacer(),
            Text(
              _formatAxis(series.end),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(width: 10),
            Text(
              'Σ ${series.failureCount}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailuresLinePainter extends CustomPainter {
  final List<int> points;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  _FailuresLinePainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 6.0;
    const top = 6.0;
    const right = 6.0;
    const bottom = 20.0;

    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = top + chartHeight * (i / 4);
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
    }

    final maxValue = math.max(1, points.reduce(math.max));
    final linePath = Path();
    final areaPath = Path();

    for (var i = 0; i < points.length; i++) {
      final t = points.length == 1 ? 0.0 : i / (points.length - 1);
      final x = left + chartWidth * t;
      final normalized = points[i] / maxValue;
      final y = top + chartHeight - chartHeight * normalized;
      final point = Offset(x, y);

      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
        areaPath.moveTo(point.dx, top + chartHeight);
        areaPath.lineTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
        areaPath.lineTo(point.dx, point.dy);
      }
    }

    areaPath.lineTo(left + chartWidth, top + chartHeight);
    areaPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FailuresLinePainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}
