import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class TestimonyScreen extends StatelessWidget {
  const TestimonyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    final testimonials = [
      _Testimonial(
        name: 'Sarah Johnson',
        role: 'Web Developer',
        imageUrl: 'https://ui-avatars.com/api/?name=Sarah+Johnson&size=200',
        rating: 5,
        comment:
            'This platform transformed my career! The courses are well-structured and the instructors are top-notch. I landed my dream job after completing the Flutter course.',
      ),
      _Testimonial(
        name: 'Michael Chen',
        role: 'Software Engineer',
        imageUrl: 'https://ui-avatars.com/api/?name=Michael+Chen&size=200',
        rating: 5,
        comment:
            'Amazing learning experience! The video quality is excellent and I can learn at my own pace. Highly recommend to anyone looking to upskill.',
      ),
      _Testimonial(
        name: 'Emily Rodriguez',
        role: 'UI/UX Designer',
        imageUrl: 'https://ui-avatars.com/api/?name=Emily+Rodriguez&size=200',
        rating: 5,
        comment:
            'Best investment in my education. The courses are practical, engaging, and really helped me understand complex concepts. Thank you!',
      ),
      _Testimonial(
        name: 'David Kim',
        role: 'Mobile Developer',
        imageUrl: 'https://ui-avatars.com/api/?name=David+Kim&size=200',
        rating: 5,
        comment:
            'The platform is user-friendly and the content is always up-to-date. I\'ve completed 5 courses so far and learned so much!',
      ),
      _Testimonial(
        name: 'Lisa Anderson',
        role: 'Product Manager',
        imageUrl: 'https://ui-avatars.com/api/?name=Lisa+Anderson&size=200',
        rating: 5,
        comment:
            'Fantastic platform! The quality of courses exceeded my expectations. I appreciate the first free video - it helped me decide before purchasing.',
      ),
      _Testimonial(
        name: 'James Wilson',
        role: 'Full Stack Developer',
        imageUrl: 'https://ui-avatars.com/api/?name=James+Wilson&size=200',
        rating: 5,
        comment:
            'Comprehensive courses with real-world projects. The support team is responsive and helpful. Five stars!',
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isMobile),
          _buildTestimonials(context, testimonials),
          _buildCTA(isMobile),
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
            'Student Testimonials',
            style: (isMobile ? AppTheme.headlineLG : AppTheme.headlineXL),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Hear what our students have to say about their learning experience',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonials(BuildContext context, List<_Testimonial> testimonials) {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = Breakpoints.getGridColumns(context).clamp(1, 3);
          return Wrap(
            spacing: AppTheme.spacingLG,
            runSpacing: AppTheme.spacingLG,
            children: testimonials.map((testimonial) {
              return SizedBox(
                width: (constraints.maxWidth - (AppTheme.spacingLG * (columns - 1))) / columns,
                child: _TestimonialCard(testimonial: testimonial),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCTA(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXL,
      ),
      padding: EdgeInsets.all(isMobile ? AppTheme.spacingXL : AppTheme.spacingXXL),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.stars,
            color: AppTheme.primaryColor,
            size: isMobile ? 48 : 64,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Join Our Happy Students',
            style: (isMobile ? AppTheme.headlineSM : AppTheme.headlineMD),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            'Start your learning journey today and be our next success story',
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Browse Courses'),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final _Testimonial testimonial;

  const _TestimonialCard({required this.testimonial});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(testimonial.imageUrl),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimonial.name,
                        style: AppTheme.titleMD,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        testimonial.role,
                        style: AppTheme.bodySM.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < testimonial.rating ? Icons.star : Icons.star_border,
                  color: AppTheme.warningColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              testimonial.comment,
              style: AppTheme.bodyMD.copyWith(
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: [
                Icon(
                  Icons.verified,
                  color: AppTheme.successColor,
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  'Verified Student',
                  style: AppTheme.bodySM.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Testimonial {
  final String name;
  final String role;
  final String imageUrl;
  final int rating;
  final String comment;

  const _Testimonial({
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.rating,
    required this.comment,
  });
}
