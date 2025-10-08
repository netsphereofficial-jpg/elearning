import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    // Sample gallery images
    final images = [
      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800',
      'https://images.unsplash.com/photo-1523580494863-6f3031224c94?w=800',
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800',
      'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=800',
      'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=800',
      'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?w=800',
      'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=800',
      'https://images.unsplash.com/photo-1531545514256-b1400bc00f31?w=800',
      'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=800',
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isMobile),
          _buildGalleryGrid(context, images),
          const SizedBox(height: AppTheme.spacingXXL),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: isMobile ? AppTheme.spacingXXL : AppTheme.spacingXXL * 2,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF9FAFB),
            Color(0xFFEBF4FF),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Gallery',
            style: (isMobile ? AppTheme.headlineLG : AppTheme.headlineXL),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Moments from our learning community',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(BuildContext context, List<String> images) {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingMD : AppTheme.spacingXL,
        vertical: AppTheme.spacingXL,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = Breakpoints.getGridColumns(context);
          return Wrap(
            spacing: AppTheme.spacingMD,
            runSpacing: AppTheme.spacingMD,
            children: images.asMap().entries.map((entry) {
              return SizedBox(
                width: (constraints.maxWidth - (AppTheme.spacingMD * (columns - 1))) / columns,
                height: 250,
                child: _GalleryItem(
                  imageUrl: entry.value,
                  index: entry.key,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _GalleryItem extends StatefulWidget {
  final String imageUrl;
  final int index;

  const _GalleryItem({
    required this.imageUrl,
    required this.index,
  });

  @override
  State<_GalleryItem> createState() => _GalleryItemState();
}

class _GalleryItemState extends State<_GalleryItem> {
  bool _isHovering = false;

  void _showImageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _showImageDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scale(_isHovering ? 0.98 : 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 60),
                  ),
                ),
                if (_isHovering)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingMD),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white),
                            SizedBox(width: AppTheme.spacingSM),
                            Text(
                              'Click to view',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
    );
  }
}
