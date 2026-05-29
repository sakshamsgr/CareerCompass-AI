import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme.dart';
import '../../services/ai_forum_service.dart';
import 'forum_post_detail_screen.dart';

class ForumFeedScreen extends StatefulWidget {
  const ForumFeedScreen({super.key});

  @override
  State<ForumFeedScreen> createState() => _ForumFeedScreenState();
}

class _ForumFeedScreenState extends State<ForumFeedScreen> {
  int _userRank = 1;
  String _userName = "User";
  String _userImage = "";
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchUserRank();
  }

  Future<void> _fetchUserRank() async {
    if (_currentUserId != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] ?? 'User';
          _userImage = data['profileImage'] ?? '';
          _userRank = AiForumService.getEducationRank(data['education'] ?? 'Class 6');
        });
      }
    }
  }

  // 🚀 NOTIFICATION DISPATCHER FOR LIKES AND AI FLAGS
  Future<void> _sendNotification({required String targetUserId, required String type, required String postId, required String postTitle, String? reason}) async {
    if (targetUserId == _currentUserId && type == 'like') return; // Don't notify if you like your own post
    
    await FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('notifications').add({
      'type': type, 
      'postId': postId,
      'postTitle': postTitle,
      'senderName': type == 'like' ? _userName : 'AI Moderator',
      'senderImage': type == 'like' ? _userImage : '',
      'parentSnippet': reason ?? '', // Repurposing snippet for AI Reason
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  void _showCreateOrEditPostDialog({String? existingPostId, String? existingTitle, String? existingContent}) {
    final titleCtrl = TextEditingController(text: existingTitle ?? "");
    final contentCtrl = TextEditingController(text: existingContent ?? "");
    bool isSubmitting = false;
    bool isEditing = existingPostId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.isDark(context) ? AppTheme.backgroundDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isDark = AppTheme.isDark(context);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? "Edit Question" : "Ask the Community", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: AppTheme.inputDecoration('Question Title', Icons.title, context),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: AppTheme.inputDecoration('Elaborate on your question...', Icons.description, context),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSubmitting ? null : () async {
                      if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                      setModalState(() => isSubmitting = true);
                      
                      final String combinedText = "${titleCtrl.text}. ${contentCtrl.text}";
                      final aiResult = await AiForumService.evaluateContent(text: combinedText, isPost: true);
                      
                      if (_currentUserId != null) {
                        final payload = {
                          'authorId': _currentUserId,
                          'authorName': _userName,
                          'authorImage': _userImage,
                          'targetRank': _userRank, 
                          'title': titleCtrl.text.trim(),
                          'content': contentCtrl.text.trim(),
                          'status': aiResult['approved'] == true ? 'approved' : 'flagged',
                          'aiRejectionReason': aiResult['reason'] ?? '',
                        };

                        if (isEditing) {
                          await FirebaseFirestore.instance.collection('forum_posts').doc(existingPostId).update(payload);
                        } else {
                          payload['createdAt'] = FieldValue.serverTimestamp();
                          payload['upvotes'] = [];
                          payload['commentCount'] = 0;
                          await FirebaseFirestore.instance.collection('forum_posts').add(payload);
                        }

                        // 🚀 SEND AI NOTIFICATION IF FLAGGED
                        if (aiResult['approved'] == false) {
                          _sendNotification(targetUserId: _currentUserId, type: 'post_flagged', postId: existingPostId ?? 'none', postTitle: titleCtrl.text.trim(), reason: aiResult['reason']);
                        }
                      }
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(aiResult['approved'] == true 
                            ? (isEditing ? 'Post updated!' : 'Post published!') 
                            : 'Post flagged for admin review: ${aiResult['reason']}'),
                          backgroundColor: aiResult['approved'] == true ? Colors.green : Colors.orange,
                        ));
                      }
                    },
                    child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(isEditing ? "Update Question" : "Post Question", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    await FirebaseFirestore.instance.collection('forum_posts').doc(postId).delete();
    final comments = await FirebaseFirestore.instance.collection('forum_comments').where('postId', isEqualTo: postId).get();
    for (var doc in comments.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _toggleUpvote(String postId, List<dynamic> currentUpvotes, Map<String, dynamic> postData) async {
    if (_currentUserId == null) return;
    final docRef = FirebaseFirestore.instance.collection('forum_posts').doc(postId);
    
    if (currentUpvotes.contains(_currentUserId)) {
      await docRef.update({'upvotes': FieldValue.arrayRemove([_currentUserId])});
    } else {
      await docRef.update({'upvotes': FieldValue.arrayUnion([_currentUserId])});
      // 🚀 SEND LIKE NOTIFICATION
      _sendNotification(targetUserId: postData['authorId'], type: 'like', postId: postId, postTitle: postData['title']);
    }
  }

  Widget _buildPostCard(QueryDocumentSnapshot post, Map<String, dynamic> data, bool isDark, Color textColor) {
    final List<dynamic> upvotes = data['upvotes'] ?? [];
    final bool isUpvoted = upvotes.contains(_currentUserId);
    final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final bool isOwner = data['authorId'] == _currentUserId;
    final bool isFlagged = data['status'] == 'flagged';

    return GestureDetector(
      onTap: isFlagged ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => ForumPostDetailScreen(postId: post.id, postData: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isFlagged ? Colors.red.withAlpha(128) : AppTheme.primaryAccent.withAlpha(51)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFlagged)
               Container(
                 margin: const EdgeInsets.only(bottom: 10),
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                 child: const Text("⚠️ Hidden pending AI review", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
               ),
            Row(
              children: [
                CircleAvatar(
                  radius: 16, backgroundColor: AppTheme.primaryAccent,
                  backgroundImage: data['authorImage'] != '' ? NetworkImage(data['authorImage']) : null,
                  child: data['authorImage'] == '' ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 8),
                Text(data['authorName'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(timeago.format(createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 18),
                    color: isDark ? AppTheme.backgroundDark : Colors.white,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showCreateOrEditPostDialog(existingPostId: post.id, existingTitle: data['title'], existingContent: data['content']);
                      } else if (value == 'delete') {
                        _deletePost(post.id);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Question')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Post', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(data['title'], style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(data['content'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleUpvote(post.id, upvotes, data),
                  child: Row(
                    children: [
                      Icon(isUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined, color: isUpvoted ? AppTheme.secondaryAccent : Colors.grey, size: 18),
                      const SizedBox(width: 6),
                      Text("${upvotes.length}", style: TextStyle(color: isUpvoted ? AppTheme.secondaryAccent : Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Icon(Icons.chat_bubble_outline, color: Colors.grey[500], size: 18),
                const SizedBox(width: 6),
                Text("${data['commentCount'] ?? 0}", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    // 🚀 ADDED TABS
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: AppTheme.primaryAccent, size: 30),
                    const SizedBox(width: 12),
                    Text("Career Community", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TabBar(
                labelColor: AppTheme.primaryAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryAccent,
                tabs: const [
                  Tab(text: "Community Feed"),
                  Tab(text: "My Posts"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // TAB 1: COMMUNITY FEED
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('forum_posts')
                          .where('status', isEqualTo: 'approved')
                          .where('targetRank', isLessThanOrEqualTo: _userRank)
                          .orderBy('targetRank', descending: true)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
                        final posts = snapshot.data!.docs;
                        if (posts.isEmpty) return Center(child: Text("No discussions available yet.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])));
                        
                        return ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                          itemCount: posts.length,
                          itemBuilder: (context, index) => _buildPostCard(posts[index], posts[index].data() as Map<String, dynamic>, isDark, textColor),
                        );
                      },
                    ),
                    
                    // TAB 2: MY POSTS (Client-side sorted to avoid needing an index)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('forum_posts')
                          .where('authorId', isEqualTo: _currentUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
                        
                        var posts = snapshot.data!.docs.toList();
                        posts.sort((a, b) {
                          Timestamp? tA = (a.data() as Map)['createdAt'] as Timestamp?;
                          Timestamp? tB = (b.data() as Map)['createdAt'] as Timestamp?;
                          if (tA == null) return -1;
                          if (tB == null) return 1;
                          return tB.compareTo(tA);
                        });

                        if (posts.isEmpty) return Center(child: Text("You haven't asked anything yet.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])));
                        
                        return ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                          itemCount: posts.length,
                          itemBuilder: (context, index) => _buildPostCard(posts[index], posts[index].data() as Map<String, dynamic>, isDark, textColor),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.secondaryAccent,
          onPressed: _showCreateOrEditPostDialog,
          icon: const Icon(Icons.edit, color: Colors.white),
          label: const Text("Ask Question", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}