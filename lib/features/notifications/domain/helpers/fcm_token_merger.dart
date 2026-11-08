/// Pure Dart utility for safely parsing, merging, and cleaning FCM notification
/// tokens in Traccar user attributes (`user.attributes['notificationTokens']`).
/// Prevents attribute clobbering, duplicate tokens, and unbounded list expansion.
class FcmTokenMerger {
  FcmTokenMerger._();

  static const int defaultMaxTokens = 3;

  /// Parses any raw representation of `notificationTokens` (null, String, or List)
  /// into a sanitized, deduplicated list of trimmed strings.
  static List<String> parseTokens(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }
    if (raw is String) {
      if (raw.trim().isEmpty) return const [];
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }
    return const [];
  }

  /// Merges [newToken] into [currentTokens] maintaining uniqueness and [maxTokens] limit.
  /// If [newToken] is 22 characters (legacy web push fid), restricts list to 22-character tokens.
  /// Retains at most [maxTokens - 1] previous tokens and appends [newToken].
  static List<String> mergeTokenList(
    List<String> currentTokens,
    String newToken, {
    int maxTokens = defaultMaxTokens,
  }) {
    final cleanToken = newToken.trim();
    if (cleanToken.isEmpty) return List.unmodifiable(currentTokens);

    var tokens = List<String>.from(currentTokens);

    if (cleanToken.length == 22) {
      tokens = tokens.where((t) => t.length == 22).toList();
    }

    if (!tokens.contains(cleanToken)) {
      if (tokens.length >= maxTokens) {
        tokens = [
          ...tokens.sublist(tokens.length - (maxTokens - 1)),
          cleanToken,
        ];
      } else {
        tokens.add(cleanToken);
      }
    }

    return List.unmodifiable(tokens);
  }

  /// Merges [newToken] into [currentAttributes] under the `'notificationTokens'` key
  /// as a comma-separated string, preserving all other attributes intact.
  static Map<String, dynamic> mergeTokenIntoAttributes(
    Map<String, dynamic>? currentAttributes,
    String newToken, {
    int maxTokens = defaultMaxTokens,
  }) {
    final cleanToken = newToken.trim();
    final updated = Map<String, dynamic>.from(currentAttributes ?? {});
    if (cleanToken.isEmpty) {
      return Map.unmodifiable(updated);
    }

    final existingTokens = parseTokens(updated['notificationTokens']);
    final mergedTokens = mergeTokenList(
      existingTokens,
      cleanToken,
      maxTokens: maxTokens,
    );

    updated['notificationTokens'] = mergedTokens.join(',');
    return Map.unmodifiable(updated);
  }

  /// Removes [tokenToRemove] from [currentAttributes], preserving other attributes.
  /// If no tokens remain, removes the `'notificationTokens'` key entirely.
  static Map<String, dynamic> removeTokenFromAttributes(
    Map<String, dynamic>? currentAttributes,
    String tokenToRemove,
  ) {
    final cleanTarget = tokenToRemove.trim();
    final updated = Map<String, dynamic>.from(currentAttributes ?? {});
    if (cleanTarget.isEmpty) {
      return Map.unmodifiable(updated);
    }

    final existingTokens = parseTokens(updated['notificationTokens']);
    final remainingTokens = existingTokens
        .where((t) => t != cleanTarget)
        .toList();

    if (remainingTokens.isEmpty) {
      updated.remove('notificationTokens');
    } else {
      updated['notificationTokens'] = remainingTokens.join(',');
    }

    return Map.unmodifiable(updated);
  }
}
