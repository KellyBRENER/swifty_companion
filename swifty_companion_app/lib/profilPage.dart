import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserProfilePage({
    super.key,
    required this.user
  });

  @override
  Widget build(BuildContext context) {
    final login = user['login']?.toString() ?? '-';
    return Scaffold(
      appBar: AppBar(title: Text(login)),
      body: _ProfileView(user: user),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final Map<String, dynamic> user;
  const _ProfileView({required this.user});

  @override
  Widget build(BuildContext context) {
    final login = user['login']?.toString() ?? '-';
    final email = user['email']?.toString() ?? '-';
    final wallet = user['wallet']?.toString() ?? '-';
    final location = user['location']?.toString() ?? 'Unavailable';

    final imageUrl = _extractImageUrl(user);

    final cursus = _pickMainCursus(user);
    final level = cursus?['level'];
    final levelText = level == null ? '-' : level.toString();

    final skills = _extractSkillsFromCursus(cursus);
    final maxLevel = skills.isEmpty
    ? 1.0
    : skills
        .map((s) {
          final lv = s['level'];
          return (lv is num) ? lv.toDouble() : double.tryParse(lv?.toString() ?? '') ?? 0.0;
        })
        .reduce((a, b) => a > b ? a : b);

    final projects = _extractProjects(user);

    final mediaSize = MediaQuery.of(context).size;
    final screenWidth = mediaSize.width;
    final screenHeight = mediaSize.height;
    final baseSize = mediaSize.shortestSide;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        children: [
          _HeaderCard(
            login: login,
            email: email,
            wallet: wallet,
            location: location,
            level: levelText,
            imageUrl: imageUrl,
          ),
          SizedBox(height: screenHeight * 0.02),
      
          // Skills
          Text('Skills', 
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: baseSize * 0.05,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          if (skills.isEmpty)
            Text('No skills available.', style: TextStyle(fontSize: baseSize * 0.04))
          else
            ...skills.map((s) => _SkillRow(skill: s, maxLevel: maxLevel)),
      
          SizedBox(height: screenHeight * 0.03),
      
          // Projects
          Text('Projects',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: baseSize * 0.05,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          if (projects.isEmpty)
            Text('No projects available.', style: TextStyle(fontSize: baseSize * 0.04))
          else
            ...projects.map((p) => _ProjectRow(project: p)),
        ],
      ),
    );
  }
}

DateTime _parseProjectDate(Map<String, dynamic> p) {
  DateTime? tryParse(String key) {
    final v = p[key];
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  return tryParse('updated_at') ??
      tryParse('created_at') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

List<Map<String, dynamic>> sortProjectsMostRecentFirst(List<Map<String, dynamic>> list) {
  list.sort((a, b) => _parseProjectDate(b).compareTo(_parseProjectDate(a)));
  return list;
}


String? _extractImageUrl(Map<String, dynamic> user) {
  final imageObj = user['image'];
  if (imageObj is Map<String, dynamic>) {
    final versions = imageObj['versions'];
    if (versions is Map<String, dynamic>) {
      return (versions['medium'] ?? versions['small'] ?? versions['large'] ?? imageObj['link'])?.toString();
    }
    return imageObj['link']?.toString();
  }
  return null;
}

/// Choix du cursus “principal”
/// Stratégie simple : prendre celui avec le level le plus élevé.
Map<String, dynamic>? _pickMainCursus(Map<String, dynamic> user) {
  final cursusUsers = user['cursus_users'];
  if (cursusUsers is! List) return null;

  Map<String, dynamic>? best;
  double bestLevel = -1;

  for (final cu in cursusUsers) {
    if (cu is! Map) continue;
    final map = Map<String, dynamic>.from(cu);
    final lv = map['level'];
    final asDouble = (lv is num) ? lv.toDouble() : double.tryParse(lv?.toString() ?? '');
    if (asDouble != null && asDouble > bestLevel) {
      bestLevel = asDouble;
      best = map;
    }
  }
  return best;
}

List<Map<String, dynamic>> _extractSkillsFromCursus(Map<String, dynamic>? cursus) {
  if (cursus == null) return [];
  final skills = cursus['skills'];
  if (skills is! List) return [];

  return skills
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// Projects: on prend projects_users et on garde failed + success.
/// Champs utiles: project.name, final_mark, status, validated?
List<Map<String, dynamic>> _extractProjects(Map<String, dynamic> user) {
  final pu = user['projects_users'];
  if (pu is! List) return [];

  final list = pu
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((e) => e['project'] is Map) // sécurité
      .toList();

  return sortProjectsMostRecentFirst(list);
}

class _HeaderCard extends StatelessWidget {
  final String login;
  final String email;
  final String wallet;
  final String location;
  final String level;
  final String? imageUrl;

  const _HeaderCard({
    required this.login,
    required this.email,
    required this.wallet,
    required this.location,
    required this.level,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final screenWidth = mediaSize.width;
    final screenHeight = mediaSize.height;
    final baseSize = mediaSize.shortestSide;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(imageUrl: imageUrl),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(login, style: TextStyle(fontSize: baseSize * 0.05, fontWeight: FontWeight.w700)),
                  SizedBox(height: screenHeight * 0.01),
                  Text('Email: $email', style: TextStyle(fontSize: baseSize * 0.035)),
                  Text('Level: $level', style: TextStyle(fontSize: baseSize * 0.035)),
                  Text('Wallet: $wallet', style: TextStyle(fontSize: baseSize * 0.035)),
                  Text('Location: $location', style: TextStyle(fontSize: baseSize * 0.035)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  const _Avatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final baseSize = MediaQuery.of(context).size.shortestSide;
    final avatarSize = baseSize * 0.16;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox(
                width: avatarSize, height: avatarSize, child: const Center(child: Icon(Icons.person)),
              ),
            )
          : SizedBox(width: avatarSize, height: avatarSize, child: const Center(child: Icon(Icons.person))),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final Map<String, dynamic> skill;
  final double maxLevel;

  const _SkillRow({
    required this.skill,
    required this.maxLevel,
  });

  @override
  Widget build(BuildContext context) {
    final name = skill['name']?.toString() ?? '-';
    final lv = skill['level'];
    final level = (lv is num) ? lv.toDouble() : double.tryParse(lv?.toString() ?? '') ?? 0.0;

    final whole = level.floorToDouble();
    final percentToNext = ((level - whole) * 100).round().clamp(0, 100);
    final toNextProgress = percentToNext / 100.0;

    // Barre “globale” : compare les skills entre eux
    final normalized = (maxLevel <= 0) ? 0.0 : (level / maxLevel).clamp(0.0, 1.0);

    final mediaSize = MediaQuery.of(context).size;
    final baseSize = mediaSize.shortestSide;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne titre
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: baseSize * 0.04),
                ),
              ),
              Text(
                'Lv ${level.toStringAsFixed(2)}  •  $percentToNext%',
                style: TextStyle(fontSize: baseSize * 0.035),
              ),
            ],
          ),
          SizedBox(height: mediaSize.height * 0.01),

          // Étoiles pour le niveau
          Row(
            children: List.generate(
              maxLevel.toInt(),
              (index) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  index < level.toInt() ? Icons.star : Icons.star_outline,
                  color: Colors.amber,
                  size: baseSize * 0.05,
                ),
              ),
            ),
          ),
          SizedBox(height: mediaSize.height * 0.008),

          // Barre secondaire (progression vers le prochain niveau)
          Opacity(
            opacity: 0.7,
            child: LinearProgressIndicator(value: toNextProgress),
          ),
        ],
      ),
    );
  }
}


class _ProjectRow extends StatelessWidget {
  final Map<String, dynamic> project;
  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final proj = project['project'] as Map;
    final name = proj['name']?.toString() ?? '-';

    final status = project['status']?.toString() ?? '-';
    final finalMark = project['final_mark'];
    final markText = finalMark == null ? '-' : finalMark.toString();

    final label = categorizeProject(project);
    
    final baseSize = MediaQuery.of(context).size.shortestSide;

    return Card(
      child: ListTile(
        title: Text(name, style: TextStyle(fontSize: baseSize * 0.04, fontWeight: FontWeight.w600)),
        subtitle: Text('Status: $status • Mark: $markText', style: TextStyle(fontSize: baseSize * 0.035)),
        trailing: Text(
          switch (label) {
            ProjectCategory.inProgress => 'In Progress',
            ProjectCategory.success => 'Success',
            ProjectCategory.failed => 'Failed',
          },
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: baseSize * 0.035,
            color: label == ProjectCategory.success ? Colors.green : 
            (label == ProjectCategory.failed ? Colors.red : Colors.blue),
          ),
        ),
      ),
    );
  }
}

enum ProjectCategory { inProgress, success, failed }

ProjectCategory categorizeProject(Map<String, dynamic> p) {
  final status = (p['status'] ?? '').toString().toLowerCase();
  final validatedRaw = p['validated?'];
  final validated = validatedRaw is bool ? validatedRaw : validatedRaw.toString() == 'true';
  final hasMark = p['final_mark'] != null;

  if (validated) return ProjectCategory.success;

  // Si terminé/mark mais pas validé => failed
  final isFinished = status.contains('finished') || status.contains('done') || status.contains('terminated');
  if (isFinished || hasMark) return ProjectCategory.failed;

  return ProjectCategory.inProgress;
}


