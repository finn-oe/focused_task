/// A thought parked in the distraction inbox (#28) while focusing, to be reviewed afterwards.
class InboxItem {
  const InboxItem({required this.id, required this.text, required this.createdAt, this.sessionId, this.resolvedAt});

  final int id;
  final String text;
  final DateTime createdAt;

  /// The focus session it was parked in, if any.
  final int? sessionId;

  /// When it was turned into a task or dismissed; `null` while it waits for review.
  final DateTime? resolvedAt;

  bool get isResolved => resolvedAt != null;

  InboxItem copyWith({DateTime? resolvedAt, bool clearResolvedAt = false}) {
    return InboxItem(id: id, text: text, createdAt: createdAt, sessionId: sessionId, resolvedAt: clearResolvedAt ? null : resolvedAt ?? this.resolvedAt);
  }

  @override
  bool operator ==(Object other) =>
      other is InboxItem && other.id == id && other.text == text && other.createdAt == createdAt && other.sessionId == sessionId && other.resolvedAt == resolvedAt;

  @override
  int get hashCode => Object.hash(id, text, createdAt, sessionId, resolvedAt);
}
