import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme.dart';
import '../forum/forum_post_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAsRead(String notificationId, String currentUserId) async {
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('notifications').doc(notificationId).update({'isRead': true});
  }

  Future<void> _deleteNotification(String notificationId, String currentUserId) async {
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('notifications').doc(notificationId).delete();
  }

  Future<void> _openPost(BuildContext context, String postId, String notificationId, String currentUserId) async {
    _markAsRead(notificationId, currentUserId);
    if (postId == '' || postId == 'none') return; // Can't open if post doesn't exist (e.g. flagged during creation)
    
    final doc = await FirebaseFirestore.instance.collection('forum_posts').doc(postId).get();
    if (doc.exists && context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ForumPostDetailScreen(postId: doc.id, postData: doc.data()!)
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return const SizedBox();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(title: Text("Notifications", style: TextStyle(color: textColor)), iconTheme: IconThemeData(color: textColor)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(child: Text("No new notifications.", style: TextStyle(color: Colors.grey[500])));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final data = notif.data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final String type = data['type'] ?? '';

              String actionText = "";
              Widget leadingIcon;
              
              // Define text and icons based on type
              if (type == 'mention') {
                actionText = "mentioned you in a comment.";
                leadingIcon = CircleAvatar(backgroundImage: data['senderImage'] != '' ? NetworkImage(data['senderImage']) : null, child: data['senderImage'] == '' ? const Icon(Icons.person) : null);
              } else if (type == 'post_reply') {
                actionText = "replied to your post.";
                leadingIcon = CircleAvatar(backgroundImage: data['senderImage'] != '' ? NetworkImage(data['senderImage']) : null, child: data['senderImage'] == '' ? const Icon(Icons.person) : null);
              } else if (type == 'like') {
                actionText = "liked your post.";
                leadingIcon = const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.thumb_up, color: Colors.white, size: 18));
              } else if (type == 'post_flagged' || type == 'comment_flagged') {
                actionText = "flagged your ${type == 'post_flagged' ? 'post' : 'comment'} for review.";
                leadingIcon = const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.warning, color: Colors.white, size: 20));
              } else {
                actionText = "interacted with you.";
                leadingIcon = const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.notifications));
              }

              String parentSnippet = data['parentSnippet'] ?? '';

              // 🚀 WRAP WITH DISMISSIBLE FOR SWIPE-TO-DELETE
              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) => _deleteNotification(notif.id, userId),
                child: InkWell(
                  onTap: () => _openPost(context, data['postId'], notif.id, userId),
                  child: Container(
                    color: isRead ? Colors.transparent : AppTheme.primaryAccent.withValues(alpha: 0.1 * 255),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leadingIcon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  children: [
                                    TextSpan(text: "${data['senderName']} ", style: TextStyle(fontWeight: FontWeight.bold, color: type.contains('flagged') ? Colors.redAccent : textColor)),
                                    TextSpan(text: actionText),
                                  ]
                                )
                              ),
                              
                              if (parentSnippet.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(border: Border(left: BorderSide(color: type.contains('flagged') ? Colors.redAccent : Colors.grey[600]!, width: 3))),
                                  child: Text('"$parentSnippet"', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                )
                              ] else ...[
                                const SizedBox(height: 4),
                                Text('"${data['postTitle']}"', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic, fontSize: 13)),
                              ],
                              
                              const SizedBox(height: 6),
                              if (createdAt != null)
                                Text(timeago.format(createdAt), style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.secondaryAccent, shape: BoxShape.circle))
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}