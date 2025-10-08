import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/course_model.dart';
import '../../services/admin_course_service.dart';

class CourseFormScreen extends StatefulWidget {
  final CourseModel? course;

  const CourseFormScreen({super.key, this.course});

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminCourseService _courseService = AdminCourseService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _thumbnailController;
  late TextEditingController _priceController;
  late TextEditingController _validityController;
  bool _isPublished = true;
  bool _isLoading = false;

  List<CourseVideo> _videos = [];

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _titleController = TextEditingController(text: course?.title ?? '');
    _descriptionController = TextEditingController(text: course?.description ?? '');
    _thumbnailController = TextEditingController(text: course?.thumbnailUrl ?? '');
    _priceController = TextEditingController(text: course?.price.toString() ?? '999');
    _validityController = TextEditingController(text: course?.validityDays.toString() ?? '30');
    _isPublished = course?.isPublished ?? true;
    _videos = course?.videos ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thumbnailController.dispose();
    _priceController.dispose();
    _validityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final course = CourseModel(
        id: widget.course?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        thumbnailUrl: _thumbnailController.text.trim(),
        price: int.parse(_priceController.text),
        validityDays: int.parse(_validityController.text),
        createdAt: widget.course?.createdAt ?? DateTime.now(),
        isPublished: _isPublished,
        videos: _videos,
      );

      bool success;
      if (widget.course == null) {
        final id = await _courseService.createCourse(course);
        success = id != null;
      } else {
        success = await _courseService.updateCourse(widget.course!.id, course);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.course == null ? 'Course created' : 'Course updated'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addVideo() {
    showDialog(
      context: context,
      builder: (context) => _VideoFormDialog(
        onSave: (video) {
          setState(() {
            _videos.add(video);
            _videos.sort((a, b) => a.order.compareTo(b.order));
          });
        },
      ),
    );
  }

  void _editVideo(int index) {
    showDialog(
      context: context,
      builder: (context) => _VideoFormDialog(
        video: _videos[index],
        onSave: (video) {
          setState(() {
            _videos[index] = video;
            _videos.sort((a, b) => a.order.compareTo(b.order));
          });
        },
      ),
    );
  }

  void _deleteVideo(int index) {
    setState(() {
      _videos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? 'New Course' : 'Edit Course'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Course Title'),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _thumbnailController,
              decoration: const InputDecoration(labelText: 'Thumbnail URL'),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid price' : null,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _validityController,
              decoration: const InputDecoration(labelText: 'Validity (days)'),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid days' : null,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            SwitchListTile(
              title: const Text('Published'),
              value: _isPublished,
              onChanged: (v) => setState(() => _isPublished = v),
            ),
            const Divider(height: AppTheme.spacingXL),
            Row(
              children: [
                Text('Videos (${_videos.length})', style: AppTheme.titleMD),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addVideo,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Video'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ..._videos.asMap().entries.map((entry) {
              final index = entry.key;
              final video = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: ListTile(
                  leading: Chip(label: Text('#${video.order}')),
                  title: Text(video.title),
                  subtitle: Text('${video.durationInSeconds}s • ${video.isFree ? "FREE" : "PAID"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editVideo(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                        onPressed: () => _deleteVideo(index),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _VideoFormDialog extends StatefulWidget {
  final CourseVideo? video;
  final Function(CourseVideo) onSave;

  const _VideoFormDialog({this.video, required this.onSave});

  @override
  State<_VideoFormDialog> createState() => _VideoFormDialogState();
}

class _VideoFormDialogState extends State<_VideoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _guidController;
  late TextEditingController _thumbController;
  late TextEditingController _durationController;
  late TextEditingController _orderController;
  bool _isFree = false;

  @override
  void initState() {
    super.initState();
    final video = widget.video;
    _titleController = TextEditingController(text: video?.title ?? '');
    _descController = TextEditingController(text: video?.description ?? '');
    _guidController = TextEditingController(text: video?.bunnyVideoGuid ?? '62d26a71-7b57-43c7-bdf2-8da954fc45c8');
    _thumbController = TextEditingController(text: video?.thumbnailUrl ?? '');
    _durationController = TextEditingController(text: video?.durationInSeconds.toString() ?? '600');
    _orderController = TextEditingController(text: video?.order.toString() ?? '1');
    _isFree = video?.isFree ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _guidController.dispose();
    _thumbController.dispose();
    _durationController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final video = CourseVideo(
      videoId: widget.video?.videoId ?? 'video_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      bunnyVideoGuid: _guidController.text.trim(),
      thumbnailUrl: _thumbController.text.trim(),
      durationInSeconds: int.parse(_durationController.text),
      order: int.parse(_orderController.text),
      isFree: _isFree,
    );

    widget.onSave(video);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.video == null ? 'Add Video' : 'Edit Video'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Video Title'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextFormField(
                controller: _guidController,
                decoration: const InputDecoration(labelText: 'Bunny Video GUID'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              TextFormField(
                controller: _thumbController,
                decoration: const InputDecoration(labelText: 'Thumbnail URL'),
              ),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration (seconds)'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
              ),
              TextFormField(
                controller: _orderController,
                decoration: const InputDecoration(labelText: 'Order'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
              ),
              SwitchListTile(
                title: const Text('Free Preview'),
                value: _isFree,
                onChanged: (v) => setState(() => _isFree = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
