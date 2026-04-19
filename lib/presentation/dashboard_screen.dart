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
  static const String _selectedTunnelKey =
      'dashboard_selected_failures_tunnel_id';
  static const String _allTunnelId = '__all__';

  static const List<Color> _linePalette = [
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFD35400),
    Color(0xFF16A085),
  ];

  final DateTime _sessionStartedAt = DateTime.now();

  String? _selectedTunnelId;
  bool _selectionLoaded = false;
  _FailuresPeriod _period = _FailuresPeriod.session;

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_selectedTunnelKey);
    if (!mounted) return;
    setState(() {
      _selectedTunnelId = selected;
      _selectionLoaded = true;
    });
  }

  Future<void> _saveSelection(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedTunnelKey, value);
  }

  void _onTunnelSelected(String value) {
    if (_selectedTunnelId == value) return;
    setState(() => _selectedTunnelId = value);
    _saveSelection(value);
  }

  void _onPeriodSelected(_FailuresPeriod value) {
    if (_period == value) return;
    setState(() => _period = value);
  }

  Future<void> _toggleTunnel(SavedTunnel tunnel) async {
    final controller = widget.tunnelsController;
    if (controller.isRunning(tunnel.id)) {
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

  _PeriodConfig _periodConfig(_FailuresPeriod period, DateTime now) {
    switch (period) {
      case _FailuresPeriod.session:
        final duration = now.difference(_sessionStartedAt);
        final safeDuration = duration <= Duration.zero
            ? const Duration(minutes: 10)
            : duration;
        final pointCount = math.max(
          12,
          math.min(80, safeDuration.inMinutes ~/ 3),
        );
        return _PeriodConfig(
          start: _sessionStartedAt,
          end: now,
          pointCount: pointCount,
          label: 'session',
        );
      case _FailuresPeriod.h1:
        return _PeriodConfig(
          start: now.subtract(const Duration(hours: 1)),
          end: now,
          pointCount: 60,
          label: '1h',
        );
      case _FailuresPeriod.h12:
        return _PeriodConfig(
          start: now.subtract(const Duration(hours: 12)),
          end: now,
          pointCount: 72,
          label: '12h',
        );
      case _FailuresPeriod.day:
        return _PeriodConfig(
          start: now.subtract(const Duration(days: 1)),
          end: now,
          pointCount: 48,
          label: 'day',
        );
      case _FailuresPeriod.week:
        return _PeriodConfig(
          start: now.subtract(const Duration(days: 7)),
          end: now,
          pointCount: 56,
          label: 'week',
        );
      case _FailuresPeriod.month:
        return _PeriodConfig(
          start: now.subtract(const Duration(days: 30)),
          end: now,
          pointCount: 60,
          label: 'month',
        );
    }
  }

  _FailureSeries _buildSeries({
    required List<DateTime> eventsUtc,
    required _PeriodConfig config,
  }) {
    final points = List<int>.filled(config.pointCount, 0);
    final spanMicros = config.end.difference(config.start).inMicroseconds;
    if (spanMicros <= 0) {
      return _FailureSeries(points: points, failureCount: 0);
    }

    for (final eventUtc in eventsUtc) {
      final event = eventUtc.toLocal();
      if (event.isBefore(config.start) || event.isAfter(config.end)) continue;

      final micros = event.difference(config.start).inMicroseconds;
      var index = ((micros / spanMicros) * config.pointCount).floor();
      if (index < 0) index = 0;
      if (index >= config.pointCount) index = config.pointCount - 1;
      points[index] += 1;
    }

    final total = points.fold<int>(0, (sum, value) => sum + value);
    return _FailureSeries(points: points, failureCount: total);
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
        final localRemoteTotal = activeCount + remoteActiveCount;

        final activeRatio = totalCount == 0 ? 0.0 : activeCount / totalCount;
        final stableRatio = totalCount == 0 ? 0.0 : stableCount / totalCount;
        final localRemoteRatio = localRemoteTotal == 0
            ? 0.0
            : activeCount / localRemoteTotal;

        var selectedTunnelId = _selectedTunnelId ?? _allTunnelId;
        final selectionValid =
            selectedTunnelId == _allTunnelId ||
            tunnels.any((t) => t.id == selectedTunnelId);
        if (!selectionValid) {
          selectedTunnelId = _allTunnelId;
          if (_selectionLoaded && _selectedTunnelId != _allTunnelId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _onTunnelSelected(_allTunnelId);
            });
          }
        }

        final periodConfig = _periodConfig(_period, DateTime.now());
        final showAll = selectedTunnelId == _allTunnelId;
        final lines = <_FailureLineSeries>[];

        if (showAll) {
          var colorIndex = 0;
          for (final tunnel in tunnels) {
            final series = _buildSeries(
              eventsUtc: controller.failureEventsFor(tunnel.id),
              config: periodConfig,
            );
            if (series.failureCount <= 0) continue;
            lines.add(
              _FailureLineSeries(
                tunnelId: tunnel.id,
                label: tunnel.name,
                color: _linePalette[colorIndex % _linePalette.length],
                series: series,
              ),
            );
            colorIndex++;
          }
        } else if (tunnels.isNotEmpty) {
          final tunnel = tunnels.firstWhere(
            (t) => t.id == selectedTunnelId,
            orElse: () => tunnels.first,
          );
          lines.add(
            _FailureLineSeries(
              tunnelId: tunnel.id,
              label: tunnel.name,
              color: Theme.of(context).colorScheme.error,
              series: _buildSeries(
                eventsUtc: controller.failureEventsFor(tunnel.id),
                config: periodConfig,
              ),
            ),
          );
        }

        final tunnelOptions = <SimpleSelectOption<String>>[
          const SimpleSelectOption(value: _allTunnelId, label: 'All'),
          ...tunnels.map((t) => SimpleSelectOption(value: t.id, label: t.name)),
        ];
        final periodOptions = const <SimpleSelectOption<_FailuresPeriod>>[
          SimpleSelectOption(value: _FailuresPeriod.session, label: 'session'),
          SimpleSelectOption(value: _FailuresPeriod.h1, label: '1h'),
          SimpleSelectOption(value: _FailuresPeriod.h12, label: '12h'),
          SimpleSelectOption(value: _FailuresPeriod.day, label: 'day'),
          SimpleSelectOption(value: _FailuresPeriod.week, label: 'week'),
          SimpleSelectOption(value: _FailuresPeriod.month, label: 'month'),
        ];

        final latestStarted =
            tunnels
                .where((t) => t.lastStartedAt != null)
                .toList(growable: false)
              ..sort((a, b) => b.lastStartedAt!.compareTo(a.lastStartedAt!));

        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final ringSectionHeight = height < 560
                ? 118.0
                : (height < 700 ? 136.0 : 158.0);
            final failuresSectionHeight = height < 560
                ? 124.0
                : (height < 700 ? 142.0 : 160.0);

            return Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _RingsSection(
                    height: ringSectionHeight,
                    activeRatio: activeRatio,
                    stableRatio: stableRatio,
                    localRemoteRatio: localRemoteRatio,
                    activeCount: activeCount,
                    totalCount: totalCount,
                    stableCount: stableCount,
                    localRemoteTotal: localRemoteTotal,
                    remoteActiveCount: remoteActiveCount,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: failuresSectionHeight,
                    child: _FailuresSection(
                      selectedTunnelId: selectedTunnelId,
                      tunnelOptions: tunnelOptions,
                      selectedPeriod: _period,
                      periodOptions: periodOptions,
                      lines: lines,
                      start: periodConfig.start,
                      end: periodConfig.end,
                      periodLabel: periodConfig.label,
                      showAll: showAll,
                      onTunnelChanged: _onTunnelSelected,
                      onPeriodChanged: _onPeriodSelected,
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
                            child: latestStarted.isEmpty
                                ? Center(
                                    child: Text(
                                      'Запуски пока не зафиксированы.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: math.min(
                                      2,
                                      latestStarted.length,
                                    ),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final tunnel = latestStarted[index];
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
  final int pointCount;
  final String label;

  const _PeriodConfig({
    required this.start,
    required this.end,
    required this.pointCount,
    required this.label,
  });
}

class _FailureSeries {
  final List<int> points;
  final int failureCount;

  const _FailureSeries({required this.points, required this.failureCount});
}

class _FailureLineSeries {
  final String tunnelId;
  final String label;
  final Color color;
  final _FailureSeries series;

  const _FailureLineSeries({
    required this.tunnelId,
    required this.label,
    required this.color,
    required this.series,
  });
}

class _RingsSection extends StatelessWidget {
  final double height;
  final double activeRatio;
  final double stableRatio;
  final double localRemoteRatio;
  final int activeCount;
  final int totalCount;
  final int stableCount;
  final int localRemoteTotal;
  final int remoteActiveCount;

  const _RingsSection({
    required this.height,
    required this.activeRatio,
    required this.stableRatio,
    required this.localRemoteRatio,
    required this.activeCount,
    required this.totalCount,
    required this.stableCount,
    required this.localRemoteTotal,
    required this.remoteActiveCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _RingTile(
              title: 'Active',
              ratio: activeRatio,
              centerValue: '$activeCount/$totalCount',
              color: Colors.green,
              extraValue: '$activeCount',
              extraCaption: 'из $totalCount',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RingTile(
              title: 'Stable',
              ratio: stableRatio,
              centerValue: '$stableCount/$totalCount',
              color: Colors.blue,
              extraValue: '$stableCount',
              extraCaption: 'без failed',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RingTile(
              title: 'Local/Remote',
              ratio: localRemoteRatio,
              centerValue: '$activeCount/$localRemoteTotal',
              color: Colors.orange,
              extraValue: '$activeCount / $remoteActiveCount',
              extraCaption: 'local / remote',
            ),
          ),
        ],
      ),
    );
  }
}

class _RingTile extends StatelessWidget {
  final String title;
  final double ratio;
  final String centerValue;
  final Color color;
  final String extraValue;
  final String extraCaption;

  const _RingTile({
    required this.title,
    required this.ratio,
    required this.centerValue,
    required this.color,
    required this.extraValue,
    required this.extraCaption,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 220;
        final ringSize = math.min(
          constraints.maxHeight - 16,
          wide ? 92.0 : 108.0,
        );

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: _AnimatedRing(
                  value: ratio,
                  color: color,
                  centerValue: centerValue,
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        extraValue,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        extraCaption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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

class _AnimatedRing extends StatelessWidget {
  final double value;
  final Color color;
  final String centerValue;

  const _AnimatedRing({
    required this.value,
    required this.color,
    required this.centerValue,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      builder: (context, animated, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(96),
              painter: _RingPainter(
                value: animated,
                color: color,
                trackColor: Theme.of(
                  context,
                ).dividerColor.withValues(alpha: 0.35),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(animated * 100).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  centerValue,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        );
      },
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
    const stroke = 8.0;
    final radius = (size.shortestSide - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _FailuresSection extends StatelessWidget {
  final String selectedTunnelId;
  final List<SimpleSelectOption<String>> tunnelOptions;
  final _FailuresPeriod selectedPeriod;
  final List<SimpleSelectOption<_FailuresPeriod>> periodOptions;
  final List<_FailureLineSeries> lines;
  final DateTime start;
  final DateTime end;
  final String periodLabel;
  final bool showAll;
  final ValueChanged<String> onTunnelChanged;
  final ValueChanged<_FailuresPeriod> onPeriodChanged;

  const _FailuresSection({
    required this.selectedTunnelId,
    required this.tunnelOptions,
    required this.selectedPeriod,
    required this.periodOptions,
    required this.lines,
    required this.start,
    required this.end,
    required this.periodLabel,
    required this.showAll,
    required this.onTunnelChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final periodWidth = constraints.maxWidth < 420 ? 78.0 : 95.0;
              return Row(
                children: [
                  Text('Сбои', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: periodWidth,
                    height: 30,
                    child: SimpleSelectField<_FailuresPeriod>(
                      value: selectedPeriod,
                      options: periodOptions,
                      onChanged: onPeriodChanged,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemExtent: 28,
                      itemSpacing: 4,
                      maxVisibleItems: 7,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: SimpleSelectField<String>(
                        value: selectedTunnelId,
                        options: tunnelOptions,
                        onChanged: onTunnelChanged,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        itemExtent: 28,
                        itemSpacing: 4,
                        maxVisibleItems: 7,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _FailuresChart(
              lines: lines,
              start: start,
              end: end,
              periodLabel: periodLabel,
              showAll: showAll,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailuresChart extends StatelessWidget {
  final List<_FailureLineSeries> lines;
  final DateTime start;
  final DateTime end;
  final String periodLabel;
  final bool showAll;

  const _FailuresChart({
    required this.lines,
    required this.start,
    required this.end,
    required this.periodLabel,
    required this.showAll,
  });

  String _fmt(DateTime dateTime) {
    final d = dateTime.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    if (periodLabel == 'week' || periodLabel == 'month') return '$day.$month';
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final visible = showAll
        ? lines
              .where((line) => line.series.failureCount > 0)
              .toList(growable: false)
        : lines;

    if (visible.isEmpty) {
      return Center(
        child: Text(
          'Нет сбоев за выбранный период',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final totalFailures = visible.fold<int>(
      0,
      (sum, line) => sum + line.series.failureCount,
    );

    return Stack(
      children: [
        CustomPaint(
          painter: _FailuresPainter(
            lines: visible,
            gridColor: Theme.of(context).dividerColor.withValues(alpha: 0.25),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 320;
              return Stack(
                children: [
                  Positioned(
                    left: 6,
                    bottom: 0,
                    child: Text(
                      _fmt(start),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!compact) ...[
                          Text(
                            _fmt(end),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 10),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'sum $totalFailures',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FailuresPainter extends CustomPainter {
  final List<_FailureLineSeries> lines;
  final Color gridColor;

  _FailuresPainter({required this.lines, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

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

    var maxY = 1;
    for (final line in lines) {
      if (line.series.points.isEmpty) continue;
      final currentMax = line.series.points.reduce(math.max);
      if (currentMax > maxY) maxY = currentMax;
    }

    for (final line in lines) {
      final points = line.series.points;
      if (points.isEmpty) continue;

      final path = Path();
      Offset? lastPoint;
      for (var i = 0; i < points.length; i++) {
        final t = points.length == 1 ? 0.0 : i / (points.length - 1);
        final x = left + chartWidth * t;
        final y = top + chartHeight - chartHeight * (points[i] / maxY);
        lastPoint = Offset(x, y);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final linePaint = Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, linePaint);
      if (lastPoint != null) {
        final endpointPaint = Paint()
          ..color = line.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(lastPoint, 3, endpointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FailuresPainter oldDelegate) {
    if (oldDelegate.lines.length != lines.length) return true;
    for (var i = 0; i < lines.length; i++) {
      final current = lines[i];
      final previous = oldDelegate.lines[i];
      if (current.tunnelId != previous.tunnelId ||
          current.color != previous.color) {
        return true;
      }
      if (current.series.points.length != previous.series.points.length) {
        return true;
      }
      for (var j = 0; j < current.series.points.length; j++) {
        if (current.series.points[j] != previous.series.points[j]) {
          return true;
        }
      }
    }
    return oldDelegate.gridColor != gridColor;
  }
}
