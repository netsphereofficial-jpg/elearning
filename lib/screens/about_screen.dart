import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(isMobile),
          _buildMissionVision(isMobile),
          _buildValues(isMobile),
          _buildTeam(isMobile),
          const SizedBox(height: AppTheme.spacingXXL),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile) {
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
            'About Us',
            style: (isMobile ? AppTheme.headlineLG : AppTheme.headlineXL),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Empowering learners worldwide with quality education',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionVision(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL * 2,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.flag,
                  title: 'Our Mission',
                  description:
                      'To make quality education accessible to everyone, everywhere. We believe that learning should be flexible, affordable, and tailored to individual needs.',
                  color: AppTheme.primaryColor,
                ),
              ),
              if (!isMobile) const SizedBox(width: AppTheme.spacingLG),
              if (!isMobile)
                Expanded(
                  child: _InfoCard(
                    icon: Icons.visibility,
                    title: 'Our Vision',
                    description:
                        'To become the world\'s leading online learning platform, where millions of students achieve their goals and transform their lives through education.',
                    color: AppTheme.secondaryColor,
                  ),
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: AppTheme.spacingLG),
            _InfoCard(
              icon: Icons.visibility,
              title: 'Our Vision',
              description:
                  'To become the world\'s leading online learning platform, where millions of students achieve their goals and transform their lives through education.',
              color: AppTheme.secondaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValues(bool isMobile) {
    final values = [
      _Value(
        icon: Icons.star,
        title: 'Excellence',
        description: 'We strive for excellence in everything we do',
      ),
      _Value(
        icon: Icons.people,
        title: 'Community',
        description: 'Building a supportive learning community',
      ),
      _Value(
        icon: Icons.lightbulb,
        title: 'Innovation',
        description: 'Constantly improving our platform and content',
      ),
      _Value(
        icon: Icons.favorite,
        title: 'Passion',
        description: 'Passionate about education and student success',
      ),
    ];

    return Container(
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL * 2,
      ),
      child: Column(
        children: [
          Text(
            'Our Values',
            style: isMobile ? AppTheme.headlineMD : AppTheme.headlineLG,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Breakpoints.getGridColumns(context);
              return Wrap(
                spacing: AppTheme.spacingLG,
                runSpacing: AppTheme.spacingLG,
                children: values.map((value) {
                  return SizedBox(
                    width: (constraints.maxWidth - (AppTheme.spacingLG * (columns - 1))) / columns,
                    child: _ValueCard(value: value),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeam(bool isMobile) {
    final team = [
      _TeamMember(
        name: 'John Doe',
        role: 'Founder & CEO',
        imageUrl: 'https://ui-avatars.com/api/?name=John+Doe&size=200',
      ),
      _TeamMember(
        name: 'Jane Smith',
        role: 'Head of Education',
        imageUrl: 'https://ui-avatars.com/api/?name=Jane+Smith&size=200',
      ),
      _TeamMember(
        name: 'Mike Johnson',
        role: 'Lead Developer',
        imageUrl: 'https://ui-avatars.com/api/?name=Mike+Johnson&size=200',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL * 2,
      ),
      child: Column(
        children: [
          Text(
            'Meet Our Team',
            style: isMobile ? AppTheme.headlineMD : AppTheme.headlineLG,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            'Dedicated professionals committed to your success',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Breakpoints.getGridColumns(context).clamp(1, 3);
              return Wrap(
                spacing: AppTheme.spacingLG,
                runSpacing: AppTheme.spacingLG,
                alignment: WrapAlignment.center,
                children: team.map((member) {
                  return SizedBox(
                    width: (constraints.maxWidth - (AppTheme.spacingLG * (columns - 1))) / columns,
                    child: _TeamCard(member: member),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(title, style: AppTheme.titleLG),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              description,
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final _Value value;

  const _ValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          children: [
            Icon(value.icon, color: AppTheme.primaryColor, size: 40),
            const SizedBox(height: AppTheme.spacingMD),
            Text(value.title, style: AppTheme.titleMD, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              value.description,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final _TeamMember member;

  const _TeamCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingLG),
          CircleAvatar(
            radius: 60,
            backgroundImage: NetworkImage(member.imageUrl),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(member.name, style: AppTheme.titleMD),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            member.role,
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLG),
        ],
      ),
    );
  }
}

class _Value {
  final IconData icon;
  final String title;
  final String description;

  const _Value({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _TeamMember {
  final String name;
  final String role;
  final String imageUrl;

  const _TeamMember({
    required this.name,
    required this.role,
    required this.imageUrl,
  });
}
