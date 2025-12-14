import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/admin_theme.dart';
import '../../services/secure_live_stream_service.dart';
import '../../models/live_stream.dart';

/// Live Stream Management Screen
/// Admin interface for managing live streams
class LiveStreamManagementScreen extends StatefulWidget {
  final bool isEmbedded;

  const LiveStreamManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<LiveStreamManagementScreen> createState() => _LiveStreamManagementScreenState();
}

class _LiveStreamManagementScreenState extends State<LiveStreamManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SecureLiveStreamService _streamService = SecureLiveStreamService();
  bool _isLoading = true;
  List<LiveStream> _allStreams = [];
  List<LiveStream> _liveStreams = [];
  List<LiveStream> _scheduledStreams = [];
  List<LiveStream> _archivedStreams = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStreams();
  }

  Future<void> _loadStreams() async {
    setState(() => _isLoading = true);

    try {
      final all = await _streamService.getStreams();
      final live = await _streamService.getLiveStreams();
      final scheduled = await _streamService.getScheduledStreams();
      final archived = await _streamService.getArchivedStreams();

      if (mounted) {
        setState(() {
          _allStreams = all;
          _liveStreams = live;
          _scheduledStreams = scheduled;
          _archivedStreams = archived;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading streams: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.primaryDark,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('إدارة البث المباشر'),
              backgroundColor: AdminTheme.secondaryDark,
            ),
      body: Column(
        children: [
          // Header with Create Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminTheme.secondaryDark,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AdminTheme.gradientPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.video_camera_back_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة البث المباشر',
                        style: AdminTheme.titleLarge,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'إنشاء وإدارة جميع البثوث المباشرة',
                        style: AdminTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateStreamDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إنشاء بث جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AdminTheme.secondaryDark,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AdminTheme.accentBlue,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.list_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('الكل (${_allStreams.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.circle, size: 12, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('مباشر (${_liveStreams.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('مجدول (${_scheduledStreams.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.archive_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('مؤرشف (${_archivedStreams.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStreamsList(_allStreams),
                      _buildStreamsList(_liveStreams),
                      _buildStreamsList(_scheduledStreams),
                      _buildStreamsList(_archivedStreams),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStreams,
        backgroundColor: AdminTheme.accentBlue,
        child: const Icon(Icons.refresh_rounded),
      ),
    );
  }

  Widget _buildStreamsList(List<LiveStream> streams) {
    if (streams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_camera_back_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بثوث',
              style: AdminTheme.bodyLarge.copyWith(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStreams,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: streams.length,
        itemBuilder: (context, index) {
          return _StreamCard(
            stream: streams[index],
            onTap: () => _showStreamDetails(streams[index]),
            onRefresh: _loadStreams,
          );
        },
      ),
    );
  }

  void _showCreateStreamDialog() {
    final titleArController = TextEditingController();
    final titleFrController = TextEditingController();
    final descArController = TextEditingController();
    final descFrController = TextEditingController();
    DateTime? scheduledDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AdminTheme.secondaryDark,
          title: const Text('إنشاء بث جديد', style: AdminTheme.titleMedium),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('العنوان بالعربية', style: AdminTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleArController,
                    style: AdminTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'أدخل عنوان البث بالعربية',
                      filled: true,
                      fillColor: AdminTheme.primaryDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('العنوان بالفرنسية', style: AdminTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleFrController,
                    style: AdminTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Entrez le titre du stream',
                      filled: true,
                      fillColor: AdminTheme.primaryDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('الوصف بالعربية (اختياري)', style: AdminTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descArController,
                    style: AdminTheme.bodyMedium,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'أدخل وصف البث',
                      filled: true,
                      fillColor: AdminTheme.primaryDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('الوصف بالفرنسية (اختياري)', style: AdminTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descFrController,
                    style: AdminTheme.bodyMedium,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Description du stream',
                      filled: true,
                      fillColor: AdminTheme.primaryDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('جدولة البث (اختياري)', style: AdminTheme.bodyMedium),
                            const SizedBox(height: 8),
                            Text(
                              scheduledDate != null
                                  ? DateFormat('yyyy-MM-dd HH:mm').format(scheduledDate!)
                                  : 'غير مجدول',
                              style: AdminTheme.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() {
                                scheduledDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded),
                      ),
                      if (scheduledDate != null)
                        IconButton(
                          onPressed: () => setState(() => scheduledDate = null),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleArController.text.isEmpty || titleFrController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال العنوان بالعربية والفرنسية')),
                  );
                  return;
                }

                Navigator.pop(context);

                final stream = await _streamService.createStream(
                  titleAr: titleArController.text,
                  titleFr: titleFrController.text,
                  descriptionAr: descArController.text.isEmpty ? null : descArController.text,
                  descriptionFr: descFrController.text.isEmpty ? null : descFrController.text,
                  scheduledAt: scheduledDate,
                );

                if (stream != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنشاء البث بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  _loadStreams();
                  _showStreamDetails(stream);
                } else {
                  if (mounted) {
                    final errorMessage = _streamService.lastError ?? 'فشل في إنشاء البث. حاول مرة أخرى.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.accentBlue,
              ),
              child: const Text('إنشاء البث'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStreamDetails(LiveStream stream) {
    showDialog(
      context: context,
      builder: (context) => _StreamDetailsDialog(
        stream: stream,
        streamService: _streamService,
        onRefresh: _loadStreams,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _streamService.dispose();
    super.dispose();
  }
}

// Stream Card Widget
class _StreamCard extends StatelessWidget {
  final LiveStream stream;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const _StreamCard({
    required this.stream,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Badge
                    _StatusBadge(status: stream.status),
                    const Spacer(),
                    // Stats
                    if (stream.isLive)
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded, size: 16, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(
                            '${stream.viewerCount}',
                            style: AdminTheme.caption,
                          ),
                        ],
                      ),
                    if (stream.isArchived || stream.isEnded)
                      Row(
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, size: 16, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(
                            '${stream.totalViews}',
                            style: AdminTheme.caption,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stream.titleAr,
                  style: AdminTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stream.titleFr != stream.titleAr) ...[
                  const SizedBox(height: 4),
                  Text(
                    stream.titleFr,
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(stream),
                      style: AdminTheme.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(LiveStream stream) {
    if (stream.isScheduled && stream.scheduledAt != null) {
      return 'مجدول: ${DateFormat('yyyy-MM-dd HH:mm').format(stream.scheduledAt!)}';
    } else if (stream.isLive && stream.startedAt != null) {
      return 'بدأ: ${DateFormat('HH:mm').format(stream.startedAt!)}';
    } else if ((stream.isEnded || stream.isArchived) && stream.endedAt != null) {
      return 'انتهى: ${DateFormat('yyyy-MM-dd HH:mm').format(stream.endedAt!)}';
    }
    return 'تاريخ غير معروف';
  }
}

// Status Badge Widget
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'live':
        color = Colors.red;
        label = 'مباشر';
        icon = Icons.circle;
        break;
      case 'scheduled':
        color = Colors.orange;
        label = 'مجدول';
        icon = Icons.schedule_rounded;
        break;
      case 'archived':
        color = Colors.blue;
        label = 'مؤرشف';
        icon = Icons.archive_rounded;
        break;
      case 'ended':
      default:
        color = Colors.grey;
        label = 'انتهى';
        icon = Icons.stop_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AdminTheme.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// Stream Details Dialog
class _StreamDetailsDialog extends StatefulWidget {
  final LiveStream stream;
  final SecureLiveStreamService streamService;
  final VoidCallback onRefresh;

  const _StreamDetailsDialog({
    required this.stream,
    required this.streamService,
    required this.onRefresh,
  });

  @override
  State<_StreamDetailsDialog> createState() => _StreamDetailsDialogState();
}

class _StreamDetailsDialogState extends State<_StreamDetailsDialog> {
  late LiveStream _stream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.stream;
  }

  Future<void> _refreshStream() async {
    final updated = await widget.streamService.getStream(_stream.id);
    if (updated != null && mounted) {
      setState(() => _stream = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: Row(
        children: [
          Expanded(
            child: Text(_stream.titleAr, style: AdminTheme.titleMedium),
          ),
          IconButton(
            onPressed: _refreshStream,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status
              _StatusBadge(status: _stream.status),
              const SizedBox(height: 20),

              // OBS Configuration (if not ended/archived)
              if (!_stream.isEnded && !_stream.isArchived) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AdminTheme.accentBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings_input_hdmi_rounded,
                            color: AdminTheme.accentBlue, size: 20),
                          const SizedBox(width: 8),
                          Text('إعدادات OBS',
                            style: AdminTheme.titleSmall.copyWith(
                              color: AdminTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCopyField('RTMP URL', widget.streamService.getRTMPUrl()),
                      const SizedBox(height: 8),
                      _buildCopyField('Stream Key', _stream.streamKey ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Playback URL (if live or archived)
              if (_stream.isLive || _stream.isArchived) ...[
                _buildInfoField('HLS URL', _stream.hlsUrl ?? 'N/A'),
                const SizedBox(height: 12),
              ],

              // Statistics
              const Text('الإحصائيات', style: AdminTheme.titleSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      'المشاهدون الحاليون',
                      _stream.viewerCount.toString(),
                      Icons.visibility_rounded,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'ذروة المشاهدين',
                      _stream.peakViewers.toString(),
                      Icons.trending_up_rounded,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      'إجمالي المشاهدات',
                      _stream.totalViews.toString(),
                      Icons.play_circle_outline_rounded,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'المدة',
                      _stream.getDurationFormatted() ?? '0s',
                      Icons.timer_rounded,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              // Actions
              const SizedBox(height: 20),
              const Text('الإجراءات', style: AdminTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_stream.isScheduled || _stream.isEnded)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          await widget.streamService.startStream(_stream.id);
                          await _refreshStream();
                          widget.onRefresh();
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_isLoading ? 'جاري البدء...' : 'بدء البث'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  if (_stream.isLive)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          await widget.streamService.endStream(_stream.id);
                          await _refreshStream();
                          widget.onRefresh();
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.stop_rounded),
                      label: Text(_isLoading ? 'جاري الإيقاف...' : 'إيقاف البث'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  if (_stream.isEnded)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          await widget.streamService.archiveStream(_stream.id);
                          await _refreshStream();
                          widget.onRefresh();
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.archive_rounded),
                      label: Text(_isLoading ? 'جاري الأرشفة...' : 'أرشفة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AdminTheme.secondaryDark,
                          title: const Text('تأكيد الحذف', style: AdminTheme.titleMedium),
                          content: const Text(
                            'هل أنت متأكد من حذف هذا البث؟ هذا الإجراء لا يمكن التراجع عنه.',
                            style: AdminTheme.bodyMedium,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await widget.streamService.deleteStream(_stream.id);
                        widget.onRefresh();
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('حذف'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildCopyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminTheme.caption),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminTheme.secondaryDark,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AdminTheme.bodySmall.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم النسخ')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminTheme.caption),
        const SizedBox(height: 4),
        Text(value, style: AdminTheme.bodyMedium),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdminTheme.titleMedium.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AdminTheme.caption.copyWith(color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}
