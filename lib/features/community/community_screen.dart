import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

enum CommunityView { comments, schemes }

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _currentIndex = 3;

  final TextEditingController _postController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  String? _replyingToCommentId;
  CommunityView _selectedView = CommunityView.comments;

  late List<CommunityComment> _comments;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.closed_caption_rounded,
      label: 'Captions',
      route: AppConstants.routeDashboard,
    ),
    _NavItem(
      icon: Icons.upload_file_rounded,
      label: 'Upload',
      route: AppConstants.routeUpload,
    ),
    _NavItem(
      icon: Icons.waving_hand_rounded,
      label: 'Gesture',
      route: AppConstants.routeGesture,
    ),
    _NavItem(
      icon: Icons.people_alt_rounded,
      label: 'Community',
      route: AppConstants.routeCommunity,
    ),
  ];

  final List<GovScheme> _schemes = const [
    GovScheme(
      title: 'UDID Card',
      category: 'Identity',
      description:
      'Apply for disability certificate services, UDID card access, status tracking, renewal, and document download.',
      applyUrl: 'https://swavlambancard.gov.in/Applyforudid',
      icon: Icons.badge_rounded,
    ),
    GovScheme(
      title: 'ADIP Scheme',
      category: 'Assistive Support',
      description:
      'Support for aids and appliances for persons with disabilities through approved agencies and service channels.',
      applyUrl: 'https://adip.depwd.gov.in/',
      icon: Icons.hearing_rounded,
    ),
    GovScheme(
      title: 'DDRS',
      category: 'Rehabilitation',
      description:
      'Deendayal Disabled Rehabilitation Scheme supporting rehabilitation services and community-based projects.',
      applyUrl: 'https://depwd.gov.in/en/ddrs/',
      icon: Icons.volunteer_activism_rounded,
    ),
    GovScheme(
      title: 'Top Class Education',
      category: 'Scholarship',
      description:
      'Financial support for students with disabilities studying in notified higher education institutions.',
      applyUrl: 'https://www.indiascienceandtechnology.gov.in/nurturing-minds/scholarships/post-graduation/scholarship-top-class-education-students-disabilities',
      icon: Icons.school_rounded,
    ),
    GovScheme(
      title: 'Scholarship Scheme for Students with Disabilities',
      category: 'Scholarship',
      description:
      'Scholarship support for eligible students with disabilities through the national scholarship platform.',
      applyUrl: 'https://depwd.gov.in/en/scholarship/',
      icon: Icons.menu_book_rounded,
    ),
    GovScheme(
      title: 'National Overseas Scholarship',
      category: 'Abroad Study',
      description:
      'Scholarship support for eligible students with disabilities pursuing higher studies abroad.',
      applyUrl: 'https://nosmsje.gov.in/',
      icon: Icons.public_rounded,
    ),
    GovScheme(
      title: 'NDFDC / Swavalamban Yojana',
      category: 'Finance',
      description:
      'Loan and self-employment related support for eligible persons with disabilities.',
      applyUrl: 'https://www.ndfdc.nic.in/schemes',
      icon: Icons.account_balance_wallet_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _comments = [
      CommunityComment(
        id: 'c1',
        userName: 'Arun',
        userRole: 'App User',
        message:
        'I liked the live captions screen. Bigger translated text would help even more in noisy places.',
        likes: 12,
        isLiked: false,
        timeLabel: '12 min ago',
        replies: [
          CommunityReply(
            id: 'r1',
            userName: 'Meena',
            message: 'Yes, and maybe a high contrast mode too.',
            likes: 3,
            isLiked: false,
            timeLabel: '8 min ago',
          ),
        ],
      ),
      CommunityComment(
        id: 'c2',
        userName: 'Dinesh',
        userRole: 'Volunteer',
        message:
        'Please add quick access cards for disability schemes so users can apply directly from the app.',
        likes: 21,
        isLiked: true,
        timeLabel: '25 min ago',
        replies: [
          CommunityReply(
            id: 'r2',
            userName: 'Prawin',
            message: 'Yes, adding 7 real schemes with apply links.',
            likes: 5,
            isLiked: true,
            timeLabel: '18 min ago',
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _postController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _openScheme(String url) async {
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open application page')),
        );
      }
    }
  }

  void _addComment() {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _comments.insert(
        0,
        CommunityComment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userName: 'You',
          userRole: 'Captrio User',
          message: text,
          likes: 0,
          isLiked: false,
          timeLabel: 'Now',
          replies: [],
        ),
      );
      _postController.clear();
      _selectedView = CommunityView.comments;
    });
  }

  void _toggleCommentLike(String commentId) {
    HapticFeedback.selectionClick();

    setState(() {
      _comments = _comments.map((comment) {
        if (comment.id == commentId) {
          final liked = !comment.isLiked;
          return comment.copyWith(
            isLiked: liked,
            likes: liked ? comment.likes + 1 : comment.likes - 1,
          );
        }
        return comment;
      }).toList();
    });
  }

  void _toggleReplyLike(String commentId, String replyId) {
    HapticFeedback.selectionClick();

    setState(() {
      _comments = _comments.map((comment) {
        if (comment.id != commentId) return comment;

        final updatedReplies = comment.replies.map((reply) {
          if (reply.id == replyId) {
            final liked = !reply.isLiked;
            return reply.copyWith(
              isLiked: liked,
              likes: liked ? reply.likes + 1 : reply.likes - 1,
            );
          }
          return reply;
        }).toList();

        return comment.copyWith(replies: updatedReplies);
      }).toList();
    });
  }

  void _startReply(String commentId, String userName) {
    HapticFeedback.lightImpact();

    setState(() {
      _replyingToCommentId = commentId;
      _replyController.text = '';
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reply to $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _replyController,
                  maxLines: 4,
                  minLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Write your reply...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(AppConstants.radiusLg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _BottomSheetButton(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomSheetButton(
                        label: 'Post Reply',
                        isPrimary: true,
                        onTap: () {
                          _submitReply();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty || _replyingToCommentId == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      _comments = _comments.map((comment) {
        if (comment.id != _replyingToCommentId) return comment;

        final updatedReplies = [
          ...comment.replies,
          CommunityReply(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userName: 'You',
            message: text,
            likes: 0,
            isLiked: false,
            timeLabel: 'Now',
          ),
        ];

        return comment.copyWith(replies: updatedReplies);
      }).toList();

      _replyController.clear();
      _replyingToCommentId = null;
      _selectedView = CommunityView.comments;
    });
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceLg,
            ),
            child: Column(
              children: [
                _TopBar(
                  user: user,
                  onProfileTap: () => context.go(AppConstants.routeProfile),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                const _Header(),
                const SizedBox(height: AppConstants.spaceMd),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 120 + bottomInset),
                    child: Column(
                      children: [
                        FadeInUp(
                          delay: const Duration(milliseconds: 70),
                          child: _CreatePostCard(
                            controller: _postController,
                            onPost: _addComment,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        FadeInUp(
                          delay: const Duration(milliseconds: 110),
                          child: _CommunitySwitch(
                            selectedView: _selectedView,
                            onChanged: (view) =>
                                setState(() => _selectedView = view),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        FadeInUp(
                          delay: const Duration(milliseconds: 160),
                          child: _selectedView == CommunityView.comments
                              ? _CommunityFeedCard(
                            comments: _comments,
                            onLikeComment: _toggleCommentLike,
                            onReplyComment: _startReply,
                            onLikeReply: _toggleReplyLike,
                          )
                              : _SchemesSection(
                            schemes: _schemes,
                            onApplyTap: _openScheme,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.navBackground.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(
              _navItems.length,
                  (i) => Expanded(
                child: _NavBarItem(
                  item: _navItems[i],
                  isActive: _currentIndex == i,
                  onTap: () => _onNavTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final dynamic user;
  final VoidCallback onProfileTap;

  const _TopBar({
    required this.user,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spaceMd,
        bottom: AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Text(
                'CAPTRIO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondary,
              size: 21,
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.name != null && user.name.toString().isNotEmpty
                      ? user.name.toString()[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Community',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _CreatePostCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPost;

  const _CreatePostCard({
    required this.controller,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share with the community',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Write a comment, idea, request, or support message...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          GestureDetector(
            onTap: onPost,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              child: const Center(
                child: Text(
                  'Post Comment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunitySwitch extends StatelessWidget {
  final CommunityView selectedView;
  final ValueChanged<CommunityView> onChanged;

  const _CommunitySwitch({
    required this.selectedView,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchTab(
              label: 'Comments',
              icon: Icons.chat_bubble_outline_rounded,
              isActive: selectedView == CommunityView.comments,
              onTap: () => onChanged(CommunityView.comments),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SwitchTab(
              label: 'Government Schemes',
              icon: Icons.account_balance_rounded,
              isActive: selectedView == CommunityView.schemes,
              onTap: () => onChanged(CommunityView.schemes),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SwitchTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.textDark : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                  isActive ? AppColors.textDark : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedCard extends StatelessWidget {
  final List<CommunityComment> comments;
  final void Function(String commentId) onLikeComment;
  final void Function(String commentId, String userName) onReplyComment;
  final void Function(String commentId, String replyId) onLikeReply;

  const _CommunityFeedCard({
    required this.comments,
    required this.onLikeComment,
    required this.onReplyComment,
    required this.onLikeReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community Feed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          if (comments.isEmpty)
            const Text(
              'No posts yet.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            )
          else
            Column(
              children: comments
                  .map(
                    (comment) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppConstants.spaceMd,
                  ),
                  child: _CommentCard(
                    comment: comment,
                    onLike: () => onLikeComment(comment.id),
                    onReply: () =>
                        onReplyComment(comment.id, comment.userName),
                    onLikeReply: (replyId) =>
                        onLikeReply(comment.id, replyId),
                  ),
                ),
              )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final CommunityComment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final ValueChanged<String> onLikeReply;

  const _CommentCard({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onLikeReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${comment.userRole} • ${comment.timeLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            comment.message,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              _ActionChip(
                icon: comment.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${comment.likes}',
                isActive: comment.isLiked,
                onTap: onLike,
              ),
              const SizedBox(width: 10),
              _ActionChip(
                icon: Icons.reply_rounded,
                label: 'Reply',
                isActive: false,
                onTap: onReply,
              ),
            ],
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Column(
              children: comment.replies
                  .map(
                    (reply) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReplyCard(
                    reply: reply,
                    onLike: () => onLikeReply(reply.id),
                  ),
                ),
              )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final CommunityReply reply;
  final VoidCallback onLike;

  const _ReplyCard({
    required this.reply,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 18),
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    reply.userName.isNotEmpty
                        ? reply.userName[0].toUpperCase()
                        : 'R',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${reply.userName} • ${reply.timeLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reply.message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _ActionChip(
            icon: reply.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: '${reply.likes}',
            isActive: reply.isLiked,
            onTap: onLike,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surface1,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemesSection extends StatelessWidget {
  final List<GovScheme> schemes;
  final Future<void> Function(String url) onApplyTap;

  const _SchemesSection({
    required this.schemes,
    required this.onApplyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Government Schemes',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          ...schemes.map(
                (scheme) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
              child: _SchemeCard(
                scheme: scheme,
                onApplyTap: () => onApplyTap(scheme.applyUrl),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final GovScheme scheme;
  final VoidCallback onApplyTap;

  const _SchemeCard({
    required this.scheme,
    required this.onApplyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
                child: Icon(
                  scheme.icon,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  scheme.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              scheme.category,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            scheme.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onApplyTap,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              child: const Center(
                child: Text(
                  'Apply Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSheetButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BottomSheetButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.primaryGradient : null,
          color: isPrimary ? null : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: isPrimary ? null : Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPrimary ? AppColors.textDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 22,
            color: isActive ? AppColors.navActive : AppColors.navInactive,
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.navActive : AppColors.navInactive,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isActive ? 18 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: AppColors.navActive,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class GovScheme {
  final String title;
  final String category;
  final String description;
  final String applyUrl;
  final IconData icon;

  const GovScheme({
    required this.title,
    required this.category,
    required this.description,
    required this.applyUrl,
    required this.icon,
  });
}

class CommunityComment {
  final String id;
  final String userName;
  final String userRole;
  final String message;
  final int likes;
  final bool isLiked;
  final String timeLabel;
  final List<CommunityReply> replies;

  const CommunityComment({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.message,
    required this.likes,
    required this.isLiked,
    required this.timeLabel,
    required this.replies,
  });

  CommunityComment copyWith({
    String? id,
    String? userName,
    String? userRole,
    String? message,
    int? likes,
    bool? isLiked,
    String? timeLabel,
    List<CommunityReply>? replies,
  }) {
    return CommunityComment(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      message: message ?? this.message,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      timeLabel: timeLabel ?? this.timeLabel,
      replies: replies ?? this.replies,
    );
  }
}

class CommunityReply {
  final String id;
  final String userName;
  final String message;
  final int likes;
  final bool isLiked;
  final String timeLabel;

  const CommunityReply({
    required this.id,
    required this.userName,
    required this.message,
    required this.likes,
    required this.isLiked,
    required this.timeLabel,
  });

  CommunityReply copyWith({
    String? id,
    String? userName,
    String? message,
    int? likes,
    bool? isLiked,
    String? timeLabel,
  }) {
    return CommunityReply(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      message: message ?? this.message,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }
}