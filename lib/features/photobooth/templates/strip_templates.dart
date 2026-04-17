// lib/features/photobooth/templates/strip_templates.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../camera/filters/filter_definitions.dart';
import '../../camera/filters/filter_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Strip Template Model
// ─────────────────────────────────────────────────────────────────────────────
class StripTemplate {
  final String id;
  final String name;
  final String category;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double spacing;
  final double borderRadius;
  final bool hasLogo;
  final bool hasDate;
  final bool hasTitle;
  final bool isPremium;
  final StripLayout layout;
  final List<Color> gradientColors;

  const StripTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryColor,
    required this.backgroundColor,
    this.borderColor = Colors.white,
    this.borderWidth = 0,
    this.spacing = 4,
    this.borderRadius = 0,
    this.hasLogo = true,
    this.hasDate = false,
    this.hasTitle = false,
    this.isPremium = false,
    this.layout = StripLayout.vertical,
    this.gradientColors = const [],
  });

  Widget buildStrip({required List<File> photos, required FilterPreset filter}) {
    return StripRenderer(
      template: this,
      photos: photos,
      filter: filter,
    );
  }
}

enum StripLayout { vertical, grid2x2, grid2x3, horizontal, collage, polaroid }

// ─────────────────────────────────────────────────────────────────────────────
// Strip Renderer
// ─────────────────────────────────────────────────────────────────────────────
class StripRenderer extends StatelessWidget {
  final StripTemplate template;
  final List<File> photos;
  final FilterPreset filter;

  const StripRenderer({
    super.key,
    required this.template,
    required this.photos,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 48;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: template.backgroundColor,
        borderRadius: BorderRadius.circular(template.borderRadius),
        gradient: template.gradientColors.length >= 2
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: template.gradientColors,
            )
          : null,
        border: template.borderWidth > 0
          ? Border.all(color: template.borderColor, width: template.borderWidth)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(template.borderRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title area
            if (template.hasTitle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: template.primaryColor.withOpacity(0.9),
                ),
                child: const Center(
                  child: Text('Photo Booth',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 2,
                    )),
                ),
              ),

            // Photos area
            Padding(
              padding: EdgeInsets.all(template.spacing * 2),
              child: _buildPhotoLayout(width),
            ),

            // Bottom bar
            if (template.hasLogo || template.hasDate)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: template.primaryColor.withOpacity(0.85),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (template.hasLogo)
                      const Text('Photo Booth',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        )),
                    if (template.hasDate)
                      Text(
                        _formatDate(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontFamily: 'Poppins',
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  Widget _buildPhotoLayout(double containerWidth) {
    if (photos.isEmpty) {
      return Container(height: 200, color: Colors.grey.withOpacity(0.2));
    }

    switch (template.layout) {
      case StripLayout.vertical:
        return _buildVertical(containerWidth);
      case StripLayout.grid2x2:
        return _buildGrid(containerWidth, 2, 2);
      case StripLayout.grid2x3:
        return _buildGrid(containerWidth, 2, 3);
      case StripLayout.horizontal:
        return _buildHorizontal(containerWidth);
      case StripLayout.polaroid:
        return _buildPolaroid(containerWidth);
      default:
        return _buildVertical(containerWidth);
    }
  }

  Widget _buildVertical(double width) {
    final imgWidth = width - template.spacing * 4;
    final imgHeight = imgWidth * 0.75;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: photos.map((photo) => Padding(
        padding: EdgeInsets.only(bottom: template.spacing),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(template.borderRadius * 0.5),
          child: FilterEngine.applyFilter(
            child: Image.file(
              photo,
              width: imgWidth,
              height: imgHeight,
              fit: BoxFit.cover,
            ),
            filter: filter,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildGrid(double width, int cols, int rows) {
    final spacing = template.spacing;
    final totalSpacing = spacing * (cols - 1);
    final imgWidth = (width - spacing * 4 - totalSpacing) / cols;
    final imgHeight = imgWidth * 0.75;

    final List<Widget> rows_ = [];
    for (int r = 0; r < rows; r++) {
      final List<Widget> rowCells = [];
      for (int c = 0; c < cols; c++) {
        final idx = r * cols + c;
        if (idx < photos.length) {
          rowCells.add(Padding(
            padding: EdgeInsets.only(
              right: c < cols - 1 ? spacing : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(template.borderRadius * 0.5),
              child: FilterEngine.applyFilter(
                child: Image.file(
                  photos[idx],
                  width: imgWidth,
                  height: imgHeight,
                  fit: BoxFit.cover,
                ),
                filter: filter,
              ),
            ),
          ));
        } else {
          rowCells.add(SizedBox(
            width: imgWidth,
            height: imgHeight,
            child: Container(color: Colors.black.withOpacity(0.1)),
          ));
        }
      }
      rows_.add(Padding(
        padding: EdgeInsets.only(bottom: r < rows - 1 ? spacing : 0),
        child: Row(children: rowCells),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows_);
  }

  Widget _buildHorizontal(double width) {
    final count = photos.length.clamp(1, 8);
    final spacing = template.spacing;
    final imgWidth = (width - spacing * 4 - spacing * (count - 1)) / count;
    final imgHeight = imgWidth * 1.33;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: photos.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(right: e.key < photos.length - 1 ? spacing : 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(template.borderRadius * 0.5),
          child: FilterEngine.applyFilter(
            child: Image.file(
              e.value,
              width: imgWidth,
              height: imgHeight,
              fit: BoxFit.cover,
            ),
            filter: filter,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildPolaroid(double width) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: photos.map((photo) {
        return Container(
          margin: EdgeInsets.only(bottom: template.spacing * 2),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
          ),
          child: ClipRRect(
            child: FilterEngine.applyFilter(
              child: Image.file(
                photo,
                width: double.infinity,
                height: (width - 72) * 0.8,
                fit: BoxFit.cover,
              ),
              filter: filter,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 100+ Strip Templates
// ─────────────────────────────────────────────────────────────────────────────
class StripTemplates {
  static List<StripTemplate> get all => [
    ..._classic,
    ..._aesthetic,
    ..._minimal,
    ..._vintage,
    ..._neon,
    ..._pastel,
    ..._dark,
    ..._holiday,
    ..._premium,
  ];

  // ── CLASSIC (12 templates)
  static const List<StripTemplate> _classic = [
    StripTemplate(id: 'cls_white', name: 'Classic White', category: 'classic',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Colors.white,
      borderWidth: 0, spacing: 4, hasLogo: true, hasDate: true, borderRadius: 4),
    StripTemplate(id: 'cls_black', name: 'Classic Black', category: 'classic',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Color(0xFF111111),
      borderWidth: 0, spacing: 4, hasLogo: true, hasDate: true, borderRadius: 4),
    StripTemplate(id: 'cls_pink', name: 'Pink Classic', category: 'classic',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Color(0xFFFFF0F5),
      spacing: 4, hasLogo: true, borderRadius: 4),
    StripTemplate(id: 'cls_gold', name: 'Gold Frame', category: 'classic',
      primaryColor: Color(0xFFFFD700), backgroundColor: Color(0xFF1A1A1A),
      borderColor: Color(0xFFFFD700), borderWidth: 2, spacing: 6,
      hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'cls_film', name: 'Film Strip', category: 'classic',
      primaryColor: Color(0xFF333333), backgroundColor: Color(0xFF1C1C1C),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'cls_portrait', name: 'Portrait', category: 'classic',
      primaryColor: Color(0xFF9B7FE8), backgroundColor: Color(0xFFF8F0FF),
      spacing: 4, hasLogo: true, hasTitle: true, borderRadius: 8),
    StripTemplate(id: 'cls_polaroid', name: 'Polaroid', category: 'classic',
      primaryColor: Colors.white, backgroundColor: Color(0xFFF5F5F0),
      spacing: 8, hasLogo: false, hasDate: true,
      borderRadius: 2, layout: StripLayout.polaroid),
    StripTemplate(id: 'cls_grid4', name: 'Grid 2x2', category: 'classic',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Colors.white,
      spacing: 4, hasLogo: true, borderRadius: 4, layout: StripLayout.grid2x2),
    StripTemplate(id: 'cls_grid6', name: 'Grid 2x3', category: 'classic',
      primaryColor: Color(0xFF9B7FE8), backgroundColor: Color(0xFF1A1A1A),
      spacing: 3, hasLogo: true, borderRadius: 0, layout: StripLayout.grid2x3),
    StripTemplate(id: 'cls_wide', name: 'Wide Strip', category: 'classic',
      primaryColor: Color(0xFF4ECDC4), backgroundColor: Colors.white,
      spacing: 4, hasLogo: true, hasDate: true,
      borderRadius: 4, layout: StripLayout.horizontal),
    StripTemplate(id: 'cls_border_white', name: 'White Border', category: 'classic',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Colors.white,
      borderColor: Colors.white, borderWidth: 3, spacing: 3,
      hasLogo: true, borderRadius: 4),
    StripTemplate(id: 'cls_border_black', name: 'Black Border', category: 'classic',
      primaryColor: Color(0xFF333333), backgroundColor: Color(0xFF0D0D0D),
      borderColor: Color(0xFF333333), borderWidth: 2, spacing: 3,
      hasLogo: true, borderRadius: 0),
  ];

  // ── AESTHETIC (14 templates)
  static const List<StripTemplate> _aesthetic = [
    StripTemplate(id: 'aes_lavender', name: 'Lavender', category: 'aesthetic',
      primaryColor: Color(0xFF9B7FE8), backgroundColor: Color(0xFFEDE7F6),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 12,
      gradientColors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5)]),
    StripTemplate(id: 'aes_rose', name: 'Rose', category: 'aesthetic',
      primaryColor: Color(0xFFE91E8C), backgroundColor: Color(0xFFFCE4EC),
      spacing: 6, hasLogo: true, borderRadius: 12,
      gradientColors: [Color(0xFFFCE4EC), Color(0xFFFFF0F5)]),
    StripTemplate(id: 'aes_peach', name: 'Peach Cream', category: 'aesthetic',
      primaryColor: Color(0xFFFF8C69), backgroundColor: Color(0xFFFFF3E0),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 12,
      gradientColors: [Color(0xFFFFF3E0), Color(0xFFFBE9E7)]),
    StripTemplate(id: 'aes_mint', name: 'Mint Dream', category: 'aesthetic',
      primaryColor: Color(0xFF4ECDC4), backgroundColor: Color(0xFFE0F2F1),
      spacing: 6, hasLogo: true, borderRadius: 12,
      gradientColors: [Color(0xFFE0F2F1), Color(0xFFE8F5E9)]),
    StripTemplate(id: 'aes_lilac', name: 'Lilac', category: 'aesthetic',
      primaryColor: Color(0xFFCE93D8), backgroundColor: Color(0xFFF3E5F5),
      spacing: 5, hasLogo: true, hasTitle: true, borderRadius: 16,
      gradientColors: [Color(0xFFF3E5F5), Color(0xFFEDE7F6)]),
    StripTemplate(id: 'aes_sakura', name: 'Sakura', category: 'aesthetic',
      primaryColor: Color(0xFFFF80AB), backgroundColor: Color(0xFFFCE4EC),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 20,
      gradientColors: [Color(0xFFFCE4EC), Color(0xFFFFE4EC)]),
    StripTemplate(id: 'aes_aurora', name: 'Aurora', category: 'aesthetic',
      primaryColor: Color(0xFF7C4DFF), backgroundColor: Color(0xFF1A1A2E),
      spacing: 4, hasLogo: true, borderRadius: 12, isPremium: false,
      gradientColors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
    StripTemplate(id: 'aes_cotton_candy', name: 'Cotton Candy', category: 'aesthetic',
      primaryColor: Color(0xFFFF80AB), backgroundColor: Color(0xFFFFE4F0),
      spacing: 8, hasLogo: true, hasDate: true, borderRadius: 16,
      gradientColors: [Color(0xFFFFE4F0), Color(0xFFE4E4FF)]),
    StripTemplate(id: 'aes_dreamy', name: 'Dreamy', category: 'aesthetic',
      primaryColor: Color(0xFF9B7FE8), backgroundColor: Color(0xFF1A0A2E),
      spacing: 6, hasLogo: true, borderRadius: 12, isPremium: false,
      gradientColors: [Color(0xFF1A0A2E), Color(0xFF0A0A1E)]),
    StripTemplate(id: 'aes_cloud', name: 'Cloud', category: 'aesthetic',
      primaryColor: Colors.white, backgroundColor: Color(0xFFF0F4FF),
      borderColor: Colors.white, borderWidth: 1,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16,
      gradientColors: [Color(0xFFF0F4FF), Color(0xFFE8ECFF)]),
    StripTemplate(id: 'aes_butter', name: 'Butter', category: 'aesthetic',
      primaryColor: Color(0xFFFFD93D), backgroundColor: Color(0xFFFFFDE7),
      spacing: 5, hasLogo: true, borderRadius: 12,
      gradientColors: [Color(0xFFFFFDE7), Color(0xFFFFF9C4)]),
    StripTemplate(id: 'aes_gradient_pink', name: 'Gradient Pink', category: 'aesthetic',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Color(0xFFFF6B9D),
      spacing: 5, hasLogo: true, hasDate: true, borderRadius: 0,
      gradientColors: [Color(0xFFFF6B9D), Color(0xFF9B7FE8)]),
    StripTemplate(id: 'aes_holographic', name: 'Holographic', category: 'aesthetic',
      primaryColor: Color(0xFF7C4DFF), backgroundColor: Color(0xFF0D0D0D),
      spacing: 4, hasLogo: true, borderRadius: 8, isPremium: true,
      gradientColors: [Color(0xFF7C4DFF), Color(0xFF00BCD4), Color(0xFFFF6B9D)]),
    StripTemplate(id: 'aes_sunset_strip', name: 'Sunset Strip', category: 'aesthetic',
      primaryColor: Color(0xFFFF6B6B), backgroundColor: Color(0xFF1A0A00),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0,
      gradientColors: [Color(0xFF1A0A00), Color(0xFF2A0A10)]),
  ];

  // ── MINIMAL (10 templates)
  static const List<StripTemplate> _minimal = [
    StripTemplate(id: 'min_clean', name: 'Clean', category: 'minimal',
      primaryColor: Color(0xFF333333), backgroundColor: Colors.white,
      spacing: 2, hasLogo: false, hasDate: false, borderRadius: 0),
    StripTemplate(id: 'min_mono', name: 'Mono', category: 'minimal',
      primaryColor: Color(0xFF111111), backgroundColor: Color(0xFFF5F5F5),
      spacing: 3, hasLogo: false, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'min_space', name: 'Space', category: 'minimal',
      primaryColor: Colors.white, backgroundColor: Colors.white,
      spacing: 12, hasLogo: false, hasDate: false, borderRadius: 0),
    StripTemplate(id: 'min_border_thin', name: 'Thin Border', category: 'minimal',
      primaryColor: Color(0xFFCCCCCC), backgroundColor: Colors.white,
      borderColor: Color(0xFFCCCCCC), borderWidth: 1,
      spacing: 2, hasLogo: false, borderRadius: 0),
    StripTemplate(id: 'min_ink', name: 'Ink', category: 'minimal',
      primaryColor: Colors.white, backgroundColor: Color(0xFF0D0D0D),
      spacing: 2, hasLogo: false, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'min_grid_w', name: 'Grid White', category: 'minimal',
      primaryColor: Color(0xFF333333), backgroundColor: Colors.white,
      spacing: 2, hasLogo: false, borderRadius: 0, layout: StripLayout.grid2x2),
    StripTemplate(id: 'min_grid_b', name: 'Grid Black', category: 'minimal',
      primaryColor: Colors.white, backgroundColor: Color(0xFF0D0D0D),
      spacing: 2, hasLogo: false, borderRadius: 0, layout: StripLayout.grid2x2),
    StripTemplate(id: 'min_studio', name: 'Studio', category: 'minimal',
      primaryColor: Color(0xFF222222), backgroundColor: Color(0xFFF0F0F0),
      borderColor: Color(0xFFDDDDDD), borderWidth: 1,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 4),
    StripTemplate(id: 'min_gallery', name: 'Gallery', category: 'minimal',
      primaryColor: Color(0xFF999999), backgroundColor: Colors.white,
      spacing: 8, hasLogo: false, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'min_frame', name: 'Frame', category: 'minimal',
      primaryColor: Color(0xFFDDDDDD), backgroundColor: Colors.white,
      borderColor: Color(0xFFDDDDDD), borderWidth: 8,
      spacing: 4, hasLogo: false, borderRadius: 0),
  ];

  // ── VINTAGE (12 templates)
  static const List<StripTemplate> _vintage = [
    StripTemplate(id: 'vnt_sepia', name: 'Sepia', category: 'vintage',
      primaryColor: Color(0xFF8D6E63), backgroundColor: Color(0xFFFFF8E1),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 4),
    StripTemplate(id: 'vnt_aged', name: 'Aged', category: 'vintage',
      primaryColor: Color(0xFFA1887F), backgroundColor: Color(0xFFFBF0E0),
      borderColor: Color(0xFFA1887F), borderWidth: 2,
      spacing: 5, hasLogo: true, hasDate: true, borderRadius: 2),
    StripTemplate(id: 'vnt_kodak', name: 'Kodak', category: 'vintage',
      primaryColor: Color(0xFFFFCC00), backgroundColor: Color(0xFFFF6600),
      spacing: 4, hasLogo: true, hasTitle: true, borderRadius: 0,
      gradientColors: [Color(0xFFF5A623), Color(0xFFD0021B)]),
    StripTemplate(id: 'vnt_instax', name: 'Instax', category: 'vintage',
      primaryColor: Colors.white, backgroundColor: Color(0xFFFFFBF0),
      borderColor: Colors.white, borderWidth: 6,
      spacing: 8, hasLogo: false, hasDate: true,
      borderRadius: 4, layout: StripLayout.polaroid),
    StripTemplate(id: 'vnt_lomo', name: 'Lomo', category: 'vintage',
      primaryColor: Color(0xFFCC0000), backgroundColor: Color(0xFF1A0000),
      spacing: 3, hasLogo: true, borderRadius: 0),
    StripTemplate(id: 'vnt_film_bw', name: 'Film B&W', category: 'vintage',
      primaryColor: Colors.white, backgroundColor: Color(0xFF1A1A1A),
      borderColor: Color(0xFF444444), borderWidth: 1,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'vnt_retro70', name: 'Retro 70s', category: 'vintage',
      primaryColor: Color(0xFFFF8C00), backgroundColor: Color(0xFF2A1800),
      spacing: 5, hasLogo: true, hasDate: true, borderRadius: 0,
      gradientColors: [Color(0xFF2A1800), Color(0xFF1A0E00)]),
    StripTemplate(id: 'vnt_disposable', name: 'Disposable', category: 'vintage',
      primaryColor: Color(0xFFDDB15E), backgroundColor: Color(0xFFFFF8DC),
      borderColor: Color(0xFFDDB15E), borderWidth: 2,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 2),
    StripTemplate(id: 'vnt_newspaper', name: 'Newspaper', category: 'vintage',
      primaryColor: Color(0xFF333333), backgroundColor: Color(0xFFF5F0E8),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'vnt_polaroid2', name: 'Polaroid Lite', category: 'vintage',
      primaryColor: Color(0xFF888888), backgroundColor: Color(0xFFF5F5F0),
      spacing: 10, hasLogo: false, hasDate: true,
      borderRadius: 2, layout: StripLayout.polaroid),
    StripTemplate(id: 'vnt_super8', name: 'Super 8', category: 'vintage',
      primaryColor: Color(0xFFBB8800), backgroundColor: Color(0xFF0D0800),
      borderColor: Color(0xFFBB8800), borderWidth: 1,
      spacing: 3, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'vnt_faded', name: 'Faded', category: 'vintage',
      primaryColor: Color(0xFFA0A0A0), backgroundColor: Color(0xFFF0EDE0),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 4),
  ];

  // ── NEON (10 templates)
  static const List<StripTemplate> _neon = [
    StripTemplate(id: 'neo_cyberpunk', name: 'Cyberpunk', category: 'neon',
      primaryColor: Color(0xFF00FFD1), backgroundColor: Color(0xFF0A0014),
      borderColor: Color(0xFF00FFD1), borderWidth: 1,
      spacing: 3, hasLogo: true, hasDate: true, borderRadius: 0,
      gradientColors: [Color(0xFF0A0014), Color(0xFF14000A)]),
    StripTemplate(id: 'neo_electric', name: 'Electric', category: 'neon',
      primaryColor: Color(0xFF00D4FF), backgroundColor: Color(0xFF000A14),
      borderColor: Color(0xFF00D4FF), borderWidth: 1,
      spacing: 3, hasLogo: true, borderRadius: 0,
      gradientColors: [Color(0xFF000A14), Color(0xFF00001E)]),
    StripTemplate(id: 'neo_pink_neon', name: 'Pink Neon', category: 'neon',
      primaryColor: Color(0xFFFF00FF), backgroundColor: Color(0xFF140014),
      borderColor: Color(0xFFFF00FF), borderWidth: 1,
      spacing: 3, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'neo_acid', name: 'Acid', category: 'neon',
      primaryColor: Color(0xFF39FF14), backgroundColor: Color(0xFF001400),
      borderColor: Color(0xFF39FF14), borderWidth: 1,
      spacing: 3, hasLogo: true, borderRadius: 0),
    StripTemplate(id: 'neo_vaporwave', name: 'Vaporwave', category: 'neon',
      primaryColor: Color(0xFFFF71CE), backgroundColor: Color(0xFF140028),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0,
      gradientColors: [Color(0xFF140028), Color(0xFF001428)]),
    StripTemplate(id: 'neo_retro_wave', name: 'Retrowave', category: 'neon',
      primaryColor: Color(0xFFFF6B6B), backgroundColor: Color(0xFF0A0014),
      spacing: 3, hasLogo: true, borderRadius: 0, isPremium: true,
      gradientColors: [Color(0xFF200028), Color(0xFF0A0014)]),
    StripTemplate(id: 'neo_tron', name: 'Tron', category: 'neon',
      primaryColor: Color(0xFF00D4FF), backgroundColor: Color(0xFF000014),
      borderColor: Color(0xFF00D4FF), borderWidth: 2,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'neo_tokyo', name: 'Neo Tokyo', category: 'neon',
      primaryColor: Color(0xFFFF4081), backgroundColor: Color(0xFF0A0A14),
      spacing: 3, hasLogo: true, borderRadius: 0, isPremium: true,
      gradientColors: [Color(0xFF0A0A14), Color(0xFF14000A)]),
    StripTemplate(id: 'neo_purple', name: 'Purple Haze', category: 'neon',
      primaryColor: Color(0xFFAA00FF), backgroundColor: Color(0xFF0A0014),
      borderColor: Color(0xFFAA00FF), borderWidth: 1,
      spacing: 3, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'neo_orange', name: 'Neon Orange', category: 'neon',
      primaryColor: Color(0xFFFF6600), backgroundColor: Color(0xFF140600),
      borderColor: Color(0xFFFF6600), borderWidth: 1,
      spacing: 3, hasLogo: true, borderRadius: 0, isPremium: true),
  ];

  // ── PASTEL (10 templates)
  static const List<StripTemplate> _pastel = [
    StripTemplate(id: 'pas_baby_pink', name: 'Baby Pink', category: 'pastel',
      primaryColor: Color(0xFFFFB3C1), backgroundColor: Color(0xFFFFF0F5),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16),
    StripTemplate(id: 'pas_sky', name: 'Sky Blue', category: 'pastel',
      primaryColor: Color(0xFF90CAF9), backgroundColor: Color(0xFFE3F2FD),
      spacing: 6, hasLogo: true, borderRadius: 16),
    StripTemplate(id: 'pas_lime', name: 'Lime', category: 'pastel',
      primaryColor: Color(0xFFC5E1A5), backgroundColor: Color(0xFFF1F8E9),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16),
    StripTemplate(id: 'pas_lemon', name: 'Lemon', category: 'pastel',
      primaryColor: Color(0xFFFFF176), backgroundColor: Color(0xFFFFFDE7),
      spacing: 6, hasLogo: true, borderRadius: 16),
    StripTemplate(id: 'pas_mauve', name: 'Mauve', category: 'pastel',
      primaryColor: Color(0xFFCE93D8), backgroundColor: Color(0xFFF3E5F5),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16),
    StripTemplate(id: 'pas_apricot', name: 'Apricot', category: 'pastel',
      primaryColor: Color(0xFFFFCC80), backgroundColor: Color(0xFFFFF8E1),
      spacing: 6, hasLogo: true, borderRadius: 16),
    StripTemplate(id: 'pas_seafoam', name: 'Seafoam', category: 'pastel',
      primaryColor: Color(0xFF80CBC4), backgroundColor: Color(0xFFE0F2F1),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16),
    StripTemplate(id: 'pas_blush', name: 'Blush', category: 'pastel',
      primaryColor: Color(0xFFEF9A9A), backgroundColor: Color(0xFFFFEBEE),
      spacing: 6, hasLogo: true, borderRadius: 16,
      gradientColors: [Color(0xFFFFEBEE), Color(0xFFFCE4EC)]),
    StripTemplate(id: 'pas_wisteria', name: 'Wisteria', category: 'pastel',
      primaryColor: Color(0xFFB39DDB), backgroundColor: Color(0xFFEDE7F6),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16),
    StripTemplate(id: 'pas_rainbow', name: 'Rainbow', category: 'pastel',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Color(0xFFFFF9F9),
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16,
      gradientColors: [Color(0xFFFFF9F9), Color(0xFFF0F0FF)]),
  ];

  // ── DARK (10 templates)
  static const List<StripTemplate> _dark = [
    StripTemplate(id: 'drk_onyx', name: 'Onyx', category: 'dark',
      primaryColor: Color(0xFF444444), backgroundColor: Color(0xFF0A0A0A),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'drk_midnight', name: 'Midnight', category: 'dark',
      primaryColor: Color(0xFF3F51B5), backgroundColor: Color(0xFF0A0A1E),
      spacing: 4, hasLogo: true, borderRadius: 8,
      gradientColors: [Color(0xFF0A0A1E), Color(0xFF050510)]),
    StripTemplate(id: 'drk_charcoal', name: 'Charcoal', category: 'dark',
      primaryColor: Color(0xFF666666), backgroundColor: Color(0xFF1A1A1A),
      borderColor: Color(0xFF333333), borderWidth: 1,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 4),
    StripTemplate(id: 'drk_obsidian', name: 'Obsidian', category: 'dark',
      primaryColor: Color(0xFF9B7FE8), backgroundColor: Color(0xFF050505),
      spacing: 3, hasLogo: true, borderRadius: 0),
    StripTemplate(id: 'drk_noir', name: 'Noir', category: 'dark',
      primaryColor: Colors.white, backgroundColor: Color(0xFF0D0D0D),
      borderColor: Colors.white, borderWidth: 1,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 0),
    StripTemplate(id: 'drk_blood', name: 'Blood', category: 'dark',
      primaryColor: Color(0xFFCC0000), backgroundColor: Color(0xFF0A0000),
      spacing: 3, hasLogo: true, borderRadius: 0,
      gradientColors: [Color(0xFF0A0000), Color(0xFF1A0000)]),
    StripTemplate(id: 'drk_shadow', name: 'Shadow', category: 'dark',
      primaryColor: Color(0xFF555555), backgroundColor: Color(0xFF111111),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 8),
    StripTemplate(id: 'drk_void', name: 'Void', category: 'dark',
      primaryColor: Color(0xFF7C4DFF), backgroundColor: Colors.black,
      spacing: 2, hasLogo: false, borderRadius: 0),
    StripTemplate(id: 'drk_slate', name: 'Slate', category: 'dark',
      primaryColor: Color(0xFF607D8B), backgroundColor: Color(0xFF0A1014),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 4),
    StripTemplate(id: 'drk_navy', name: 'Navy', category: 'dark',
      primaryColor: Color(0xFF1565C0), backgroundColor: Color(0xFF050A14),
      spacing: 4, hasLogo: true, borderRadius: 4,
      gradientColors: [Color(0xFF050A14), Color(0xFF0A0514)]),
  ];

  // ── HOLIDAY (10 templates)
  static const List<StripTemplate> _holiday = [
    StripTemplate(id: 'hol_christmas', name: 'Christmas', category: 'holiday',
      primaryColor: Color(0xFFCC0000), backgroundColor: Color(0xFF0A2010),
      borderColor: Color(0xFFCC0000), borderWidth: 2,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 4,
      isPremium: true),
    StripTemplate(id: 'hol_halloween', name: 'Halloween', category: 'holiday',
      primaryColor: Color(0xFFFF6600), backgroundColor: Color(0xFF0A0500),
      spacing: 3, hasLogo: true, hasDate: true, borderRadius: 0,
      isPremium: true),
    StripTemplate(id: 'hol_valentines', name: 'Valentine', category: 'holiday',
      primaryColor: Color(0xFFE91E63), backgroundColor: Color(0xFFFCE4EC),
      borderColor: Color(0xFFE91E63), borderWidth: 2,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 16, isPremium: true),
    StripTemplate(id: 'hol_birthday', name: 'Birthday', category: 'holiday',
      primaryColor: Color(0xFFFFD700), backgroundColor: Color(0xFF1A0A28),
      spacing: 5, hasLogo: true, hasTitle: true, hasDate: true, borderRadius: 12,
      isPremium: true,
      gradientColors: [Color(0xFF1A0A28), Color(0xFF280A1A)]),
    StripTemplate(id: 'hol_new_year', name: 'New Year', category: 'holiday',
      primaryColor: Color(0xFFFFD700), backgroundColor: Color(0xFF0A0A28),
      borderColor: Color(0xFFFFD700), borderWidth: 1,
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 4,
      isPremium: true),
    StripTemplate(id: 'hol_diwali', name: 'Diwali', category: 'holiday',
      primaryColor: Color(0xFFFF8F00), backgroundColor: Color(0xFF1A0800),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 8,
      isPremium: true,
      gradientColors: [Color(0xFF1A0800), Color(0xFF280E00)]),
    StripTemplate(id: 'hol_holi', name: 'Holi', category: 'holiday',
      primaryColor: Color(0xFFFF6B9D), backgroundColor: Color(0xFFFFF9F9),
      spacing: 5, hasLogo: true, hasDate: true, borderRadius: 12,
      isPremium: true,
      gradientColors: [Color(0xFFFFF0FF), Color(0xFFF0FFF0)]),
    StripTemplate(id: 'hol_summer', name: 'Summer Vibes', category: 'holiday',
      primaryColor: Color(0xFFFF8C69), backgroundColor: Color(0xFF0A1420),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 8, isPremium: false,
      gradientColors: [Color(0xFF0A1420), Color(0xFF14200A)]),
    StripTemplate(id: 'hol_graduation', name: 'Graduation', category: 'holiday',
      primaryColor: Color(0xFFFFD700), backgroundColor: Color(0xFF0A0000),
      borderColor: Color(0xFFFFD700), borderWidth: 2,
      spacing: 5, hasLogo: true, hasTitle: true, hasDate: true, borderRadius: 0,
      isPremium: true),
    StripTemplate(id: 'hol_wedding', name: 'Wedding', category: 'holiday',
      primaryColor: Color(0xFFFFD700), backgroundColor: Color(0xFFFFFBF0),
      borderColor: Color(0xFFFFD700), borderWidth: 3,
      spacing: 8, hasLogo: true, hasDate: true,
      borderRadius: 4, layout: StripLayout.polaroid, isPremium: true),
  ];

  // ── PREMIUM EXCLUSIVE (12+ templates)
  static const List<StripTemplate> _premium = [
    StripTemplate(id: 'prm_luxury', name: 'Luxury Gold', category: 'premium',
      primaryColor: Color(0xFFFFD700), backgroundColor: Color(0xFF0A0800),
      borderColor: Color(0xFFFFD700), borderWidth: 2,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 0, isPremium: true,
      gradientColors: [Color(0xFF0A0800), Color(0xFF1A1000)]),
    StripTemplate(id: 'prm_diamond', name: 'Diamond', category: 'premium',
      primaryColor: Color(0xFF00D4FF), backgroundColor: Color(0xFF050A14),
      borderColor: Color(0xFF00D4FF), borderWidth: 1,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 12, isPremium: true),
    StripTemplate(id: 'prm_rose_gold', name: 'Rose Gold', category: 'premium',
      primaryColor: Color(0xFFE8A598), backgroundColor: Color(0xFF1A0A08),
      borderColor: Color(0xFFE8A598), borderWidth: 2,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 8, isPremium: true),
    StripTemplate(id: 'prm_platinum', name: 'Platinum', category: 'premium',
      primaryColor: Color(0xFFE0E0E0), backgroundColor: Color(0xFF0A0A0A),
      borderColor: Color(0xFFE0E0E0), borderWidth: 1,
      spacing: 6, hasLogo: true, hasDate: true, borderRadius: 0, isPremium: true),
    StripTemplate(id: 'prm_celestial', name: 'Celestial', category: 'premium',
      primaryColor: Color(0xFF7C4DFF), backgroundColor: Color(0xFF050014),
      spacing: 5, hasLogo: true, hasDate: true, borderRadius: 16, isPremium: true,
      gradientColors: [Color(0xFF050014), Color(0xFF0A0A28)]),
    StripTemplate(id: 'prm_galaxy', name: 'Galaxy', category: 'premium',
      primaryColor: Color(0xFF9B7FE8), backgroundColor: Color(0xFF050A1E),
      spacing: 4, hasLogo: true, hasDate: true, borderRadius: 8, isPremium: true,
      gradientColors: [Color(0xFF050A1E), Color(0xFF0A051E)]),
  ];
}
