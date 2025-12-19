/// Qleon Firebase Constants
/// ------------------------------------------------------------
/// IMPORTANT RULES:
/// - NO secrets or API keys in this file
/// - NO logic, only static constants
/// - Used across services, repositories, and rules mapping
/// ------------------------------------------------------------

/// -------------------------------
/// FIREBASE COLLECTION NAMES
/// -------------------------------
class FirebaseCollections {
  FirebaseCollections._();

  static const String users = 'users';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String groups = 'groups';
}

/// -------------------------------
/// FIREBASE FIELD NAMES
/// -------------------------------
class FirebaseFields {
  FirebaseFields._();

  // Common
  static const String id = 'id';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  // User
  static const String uid = 'uid';
  static const String username = 'username';
  static const String photoUrl = 'photoUrl';
  static const String publicKey = 'publicKey';
  static const String lastSeen = 'lastSeen';
  static const String isOnline = 'isOnline';

  // Chat
  static const String type = 'type'; // private | group
  static const String members = 'members';
  static const String admins = 'admins';
  static const String lastMessage = 'lastMessage';
  static const String mutedBy = 'mutedBy';

  // Message
  static const String senderId = 'senderId';
  static const String encryptedContent = 'encryptedContent';
  static const String encryptedKey = 'encryptedKey';
  static const String messageType = 'messageType';
  static const String timestamp = 'timestamp';
  static const String isDeleted = 'isDeleted';
  static const String readBy = 'readBy';

  // Group
  static const String groupName = 'groupName';
  static const String groupAvatar = 'groupAvatar';
}

/// -------------------------------
/// CHAT & MESSAGE TYPES
/// -------------------------------
class FirebaseChatTypes {
  FirebaseChatTypes._();

  static const String privateChat = 'private';
  static const String groupChat = 'group';
}

class FirebaseMessageTypes {
  FirebaseMessageTypes._();

  static const String text = 'text';
  static const String image = 'image';
  static const String voice = 'voice';
  static const String system = 'system';
}

/// -------------------------------
/// FIREBASE QUERY LIMITS
/// -------------------------------
class FirebaseLimits {
  FirebaseLimits._();

  static const int chatListLimit = 50;
  static const int messageFetchLimit = 30;
}

/// -------------------------------
/// FIREBASE STORAGE PATHS
/// -------------------------------
class FirebaseStoragePaths {
  FirebaseStoragePaths._();

  static const String profileImages = 'profile_images';
  static const String chatMedia = 'chat_media';
}

/// -------------------------------
/// FIREBASE CLOUD MESSAGING KEYS
/// -------------------------------
class FirebaseMessagingKeys {
  FirebaseMessagingKeys._();

  /// Used in FCM data payload
  static const String chatId = 'chatId';
  static const String senderId = 'senderId';
  static const String messageId = 'messageId';
  static const String type = 'type'; // silent | alert
}

/// -------------------------------
/// FIREBASE ERROR CODES (COMMON)
/// -------------------------------
class FirebaseErrorCodes {
  FirebaseErrorCodes._();

  static const String permissionDenied = 'permission-denied';
  static const String notFound = 'not-found';
  static const String unavailable = 'unavailable';
  static const String unauthenticated = 'unauthenticated';
}