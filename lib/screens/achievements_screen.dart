import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/services/achievements_helper.dart';
import 'package:sophia_path/services/user_stats_service.dart';
import 'package:share_plus/share_plus.dart';
import '../models/achievements.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  bool _isLoading = true;
  int _selectedFilter = 0; // 0: All, 1: Completed, 2: In Progress

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _achievements = await AchievementsHelper.calculateAchievementsProgress();
    setState(() => _isLoading = false);
  }

  List<Achievement> get _filteredAchievements {
    List<Achievement> filtered = _achievements;

    if (_selectedFilter == 1) {
      filtered = filtered.where((a) => a.isCompleted).toList();
    } else if (_selectedFilter == 2) {
      filtered = filtered.where((a) => !a.isCompleted).toList();
    }

    // Sort by progress (highest first), then by completion
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return b.isCompleted ? 1 : -1;
      }
      return b.percentage.compareTo(a.percentage);
    });

    return filtered;
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final theme = Theme.of(context);
    final isCompleted = achievement.isCompleted;
    final progress = achievement.percentage;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.02,
        vertical: 8,
      ),
      elevation: isCompleted ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted
              ? achievement.color.withValues(alpha: 0.5)
              : Colors.transparent,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: isCompleted
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    achievement.color.withValues(alpha: 0.1),
                    achievement.color.withValues(alpha: 0.05),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width * 0.03,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? achievement.color.withValues(alpha: 0.2)
                          : achievement.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      achievement.icon,
                      color: isCompleted
                          ? achievement.color
                          : achievement.color.withValues(alpha: 0.7),
                      size: MediaQuery.of(context).size.width * 0.07,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                achievement.name,
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.045,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompleted)
                              Container(
                                padding: EdgeInsets.all(
                                  MediaQuery.of(context).size.width * 0.01,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size:
                                      MediaQuery.of(context).size.width * 0.04,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.005,
                        ),
                        Text(
                          achievement.type.name.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            color: achievement.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.015),
              Text(
                achievement.description,
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width * 0.035,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.033,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        '${achievement.progress.toInt()}/${achievement.target.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.033,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.outline.withValues(
                      alpha: 0.2,
                    ),
                    color: achievement.color,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: MediaQuery.of(context).size.height * 0.01,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.008),
                  Text(
                    '${(progress * 100).toInt()}% complete',
                    style: GoogleFonts.poppins(
                      fontSize: MediaQuery.of(context).size.width * 0.03,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final completedCount = _achievements.where((a) => a.isCompleted).length;
    final totalCount = _achievements.length;

    final inProgressCount = totalCount - completedCount;
    final averageProgress = totalCount > 0
        ? (_achievements.fold(0.0, (sum, a) => sum + a.percentage) /
                  totalCount *
                  100)
              .toInt()
        : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          children: [
            Text(
              'Achievement Stats',
              style: GoogleFonts.poppins(
                fontSize: screenWidth * 0.055,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  value: completedCount.toString(),
                  label: 'Completed',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                Container(
                  width: 1,
                  height: screenWidth * 0.1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                _buildStatItem(
                  value: inProgressCount.toString(),
                  label: 'In Progress',
                  icon: Icons.timelapse,
                  color: Colors.orange,
                ),
                Container(
                  width: 1,
                  height: screenWidth * 0.1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                _buildStatItem(
                  value: '$averageProgress%',
                  label: 'Avg Progress',
                  icon: Icons.trending_up,
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.025),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: screenWidth * 0.05),
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: screenWidth * 0.028,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSelected = _selectedFilter == index;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? index : 0;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF3D5CFF).withValues(alpha: 0.2),
      labelStyle: GoogleFonts.poppins(
        fontSize: screenWidth * 0.035,
        color: isSelected ? const Color(0xFF3D5CFF) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      checkmarkColor: const Color(0xFF3D5CFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF3D5CFF).withValues(alpha: 0.5)
              : Colors.grey[300]!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final filteredAchievements = _filteredAchievements;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Achievements',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3D5CFF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(screenWidth * 0.04),
                children: [
                  _buildStatsCard(),
                  SizedBox(height: screenWidth * 0.06),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Achievements',
                        style: GoogleFonts.poppins(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenWidth * 0.015,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D5CFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_achievements.where((a) => a.isCompleted).length}/${_achievements.length}',
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.035,
                            color: const Color(0xFF3D5CFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.04),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(0, 'All'),
                        SizedBox(width: screenWidth * 0.02),
                        _buildFilterChip(1, 'Completed'),
                        SizedBox(width: screenWidth * 0.02),
                        _buildFilterChip(2, 'In Progress'),
                      ],
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.05),
                  if (filteredAchievements.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: screenWidth * 0.2),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFilter == 1
                                  ? Icons.celebration
                                  : Icons.search_off,
                              size: screenWidth * 0.2,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            Text(
                              _selectedFilter == 1
                                  ? 'No completed achievements yet!'
                                  : _selectedFilter == 2
                                  ? 'All achievements completed!'
                                  : 'No achievements found',
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.04,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredAchievements.map((achievement) {
                      return _buildAchievementCard(achievement);
                    }),
                  SizedBox(height: screenWidth * 0.15),
                ],
              ),
            ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: screenWidth * 0.05),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final statsService = UserStatsService();
            await statsService.getShareCount();

            final shareText =
                '''
🏆 My Achievements Progress 🏆

✅ Completed: ${_achievements.where((a) => a.isCompleted).length}/${_achievements.length} achievements

🎯 Top Achievements:
${_achievements.where((a) => a.isCompleted).take(3).map((a) => '• ${a.name}').join('\n')}

Keep pushing for greatness! 💪

#Achievements #LearningGoals #Progress
            ''';

            // ignore: deprecated_member_use
            await Share.share(shareText);
            await statsService.incrementShareCount();
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
          backgroundColor: const Color(0xFF3D5CFF),
        ),
      ),
    );
  }
}
