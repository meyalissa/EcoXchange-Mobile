import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_hero_header.dart';
import '../../data/models/rider_pickup_action.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../providers/rider_pickup_list_provider.dart';
import '../providers/rider_tasks_provider.dart';
import '../widgets/rider_action_runner.dart';
import '../widgets/rider_task_card.dart';
import 'rider_pickup_detail_screen.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "Wednesday, 1 October 2026" for the hero subtitle.
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// EcoXchange Mobile — Rider My Tasks (02_rider_tasks design): the rider's
/// jobs split into Pending (assigned, waiting to be accepted), Ongoing
/// (accepted / en route / collecting) and Completed — all from the real
/// `GET /rider/pickups`. "Accept Task" / "Continue" run the job's single
/// next action through the shared rider action flow; the lists re-read
/// afterwards.
class RiderTasksScreen extends StatefulWidget {
  const RiderTasksScreen({super.key, this.onChanged});

  /// Called after a confirmed action so other tabs can refresh.
  final VoidCallback? onChanged;

  @override
  State<RiderTasksScreen> createState() => _RiderTasksScreenState();
}

class _RiderTasksScreenState extends State<RiderTasksScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tasks = context.read<RiderTasksProvider>();
      if (!tasks.loadedOnce && !tasks.isLoading) tasks.load();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<RiderTasksProvider>().refresh(), context.read<RiderPickupListProvider>().refresh()]);
  }

  Future<void> _afterChange() async {
    await _refresh();
    widget.onChanged?.call();
  }

  void _openDetail(RiderPickupSummary pickup) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: pickup.id)))
        .then((_) => _afterChange());
  }

  Future<void> _runNext(RiderPickupSummary pickup, RiderPickupAction expected) async {
    if (await runNextActionForPickup(context, pickup.id, expected: expected)) await _afterChange();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<RiderTasksProvider>();
    final completed = context.watch<RiderPickupListProvider>();
    final completedCount = completed.pagination?.total ?? completed.pickups.length;

    final labels = [
      'Pending (${tasks.pending.length})',
      'Ongoing (${tasks.ongoing.length})',
      'Completed ($completedCount)',
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: EcoHeroHeader(
              subtitle: longDate(DateTime.now()),
              title: 'My Tasks',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadii.rFull)),
                child: Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          key: Key('tasks-tab-$i'),
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tab == i ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadii.rFull),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[i],
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _tab == i ? AppColors.green700 : Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_tab < 2) ..._openSliver(tasks, _tab == 0 ? tasks.pending : tasks.ongoing) else ..._completedSliver(completed),
        ],
      ),
    );
  }

  List<Widget> _openSliver(RiderTasksProvider tasks, List<RiderPickupSummary> list) {
    if (!tasks.loadedOnce) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncStateView<bool>(isLoading: tasks.isLoading, error: tasks.error, data: null, onRetry: tasks.load, builder: (_, _) => const SizedBox()),
        ),
      ];
    }
    if (list.isEmpty) {
      return [
        _EmptySliver(text: _tab == 0 ? 'No tasks waiting for you to accept.' : 'No ongoing tasks right now.'),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        sliver: SliverList.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final p = list[i];
            final next = RiderPickupAction.nextFor(p.displayStatus);
            return RiderTaskCard(
              key: Key('task-${p.id}'),
              pickup: p,
              onTap: () => _openDetail(p),
              actions: [
                OutlinedButton(key: Key('task-details-${p.id}'), onPressed: () => _openDetail(p), child: const Text('View Details')),
                if (next != null)
                  FilledButton(
                    key: Key('task-action-${p.id}'),
                    onPressed: () => _runNext(p, next),
                    child: Text(next == RiderPickupAction.accept ? 'Accept Task' : riderActionCopy(next).button, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _completedSliver(RiderPickupListProvider completed) {
    if (completed.pagination == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncStateView<bool>(
            isLoading: completed.isLoading,
            error: completed.error,
            data: null,
            onRetry: completed.load,
            builder: (_, _) => const SizedBox(),
          ),
        ),
      ];
    }
    final list = completed.pickups;
    if (list.isEmpty) return [const _EmptySliver(text: 'No completed tasks yet.')];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        sliver: SliverList.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => RiderTaskCard(key: Key('task-${list[i].id}'), pickup: list[i], onTap: () => _openDetail(list[i])),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: completed.hasMore
              ? OutlinedButton(
                  onPressed: completed.isLoadingMore ? null : completed.loadMore,
                  child: Text(completed.isLoadingMore ? 'Loading…' : 'Load more'),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ];
  }
}

class _EmptySliver extends StatelessWidget {
  const _EmptySliver({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_available_outlined, size: 52, color: AppColors.n300),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.n600)),
          ],
        ),
      ),
    );
  }
}
