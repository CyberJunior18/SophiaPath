# sophia_path

A new Flutter project.


fx : function
P : Procedure ( void )
() : parameter
v : variable

lib
    - models
                -chat
                        chat_contact.dart
                                            ChatContact : chat list row data model
                                                    ()   String userId
                                                    ()   String chatId
                                                    ()   DateTime lastMessageTime
                                                    ()   String lastMessage
                                                    ()   int unreadCount (default 0)
                                                    fx   toMap : serialize to Map (lastMessageTime as ISO string)
                                                    fx   ChatContact.fromMap : create from Map (parses lastMessageTime)
                                                    fx   copyWith : clone with selective overrides

                        ChatMessage.dart
                                            MessageStatus : enum for status of message (sending, sent, delivered, read, failed)
                                            MessageType : enum for message type (text, image, file, system)
                                            ChatMessage : class for message in chat :
                                                    ()   MessageStatus status
                                                    ()   MessageType type
                                                    ()   String id , senderId, senderName, message
                                                    ()   DateTime timestamp
                                                    ()   bool isRead
                                                    ()   Map<String, String> reactions

                                                    fx   Map<String, dynamic> toMap : changes content to map  
                                                    fx   factory ChatMessage.fromMap(Map<String, dynamic> map) : Takes a Map (key–value data) & Returns a ChatMessage
                                                    fx   copywith : copy another ChatMessage with ability to change any value
    - screens
                -chat
                        chat_screen.dart
                                            ChatScreen (StatefulWidget)
                                                    ()   User? chatUser : the user you are chatting with
                                                    ()   String? chatId : unique identifier for the chat

                                            _ChatScreenState
                                                    v    TextEditingController _messageController : controller for message input field
                                                    v    List<ChatMessage> _messages : list of ChatMessages displayed in the chat
                                                    v    User _currentUser : the current logged-in user
                                                    v    bool _isLoading : loading state flag for initial message load
                                                    v    bool _isTyping : flag to track if user is currently typing
                                                    v    Timer? _typingTimer : timer for debouncing typing indicator

                                                    P    initState : initializes the screen by loading current user & messages
                                                    P    _loadCurrentUser : fetches the current logged-in user from ProfileState
                                                    P    _loadMessages : loads chat messages from database/API (with 500ms delay)
                                                    P    _onTextChanged(String text) : detects text input & manages typing indicator with 2s debounce
                                                    P    _sendTypingIndicator(bool isTyping) : sends typing status to server (empty stub)
                                                    P    _sendMessage : creates & adds a new ChatMessage to _messages list, clears input field
                                                    P    _showMessageOptions(ChatMessage message) : displays modal with Reply, Edit, Delete, Report options
                                                    P    _replyToMessage(ChatMessage message) : prepares message controller for reply (TODO)
                                                    P    _editMessage(ChatMessage message) : loads message text into controller for editing (TODO)
                                                    P    _deleteMessage(ChatMessage message) : removes message from _messages list
                                                    P    _reportMessage(ChatMessage message) : reports message & shows snackbar (TODO)
                                                    P    _showReactions(ChatMessage message) : displays emoji reactions picker (8 emojis: 👍❤️😂😮😢🙏🎉🔥)
                                                    P    _addReactionToMessage(ChatMessage message, String emoji) : adds/updates emoji reaction from current user
                                                    P    build : creates UI with AppBar (user info), message list, & message input field    

                        chats_list_screen.dart
                                            ChatsListScreen (StatefulWidget)
                                                    ()   no parameters

                                            _ChatsListScreenState
                                                    v    List<ChatContact> _contacts : chat contact rows shown in list
                                                    v    List<User> _chatUsers : user profiles corresponding to contacts
                                                    v    bool _isLoading : loading flag during initial fetch

                                                    P    initState : triggers loading of chat contacts
                                                    P    _loadChatContacts : simulates fetch (500ms), seeds sample users and contacts, clears loading flag
                                                    P    _buildChatItem(ChatContact contact) : builds each chat row with avatar, name, last message, unread/online badge, and navigates to ChatScreen on tap
                                                    P    _showChatOptions(ChatContact contact, User user) : bottom sheet menu (mute, pin, block, delete)
                                                    P    _muteChat(ChatContact contact) : placeholder for muting notifications
                                                    P    _pinChat(ChatContact contact) : placeholder for pinning chat
                                                    P    _blockUser(User user) : placeholder for blocking user
                                                    P    _deleteChat(ChatContact contact) : removes chat from contacts list
                                                    P    _archiveChat(ChatContact contact) : archives chat by removing from list
                                                    P    _showDeleteConfirmation(ChatContact contact) : confirms delete via dialog
                                                    P    _formatTime(DateTime time) : formats timestamp as HH:mm, Yesterday, or d/m
                                                    P    build : renders scaffold with app bar, search field, pull-to-refresh list (Dismissible for delete/archive), and FAB to start new chat

    - services
                - chat
                        chat_service.dart
                                            ChatService (singleton)
                                                    v    SharedPreferences _prefs : local key-value store (async getter)

                                                    fx   saveContact(ChatContact contact) : upsert a contact into prefs list
                                                    fx   getContacts() : read all saved contacts from prefs
                                                    fx   saveMessage(String chatId, ChatMessage message) : append message to chat, update contact last message/unread
                                                    fx   getMessages(String chatId) : read messages for chat from prefs
                                                    fx   getContactByUserId(String userId) : lookup contact by user id
                                                    fx   _getCurrentUserId() : fetch current user id from prefs (fallback stub)
                                                    fx   _getCurrentUserFromPrefs() : stub fallback user id
                                                    fx   markMessagesAsRead(String chatId) : mark all messages read and reset contact unread count
                                                    fx   clearChatHistory(String chatId) : remove stored messages for chat
                                                    fx   getContactByChatId(String chatId) : lookup contact by chat id
                                                    fx   createChat(String otherUserId) : create contact + chat id seed and persist
                                                    fx   deleteContact(String userId) : remove contact by user id
                                                    fx   getTotalUnreadCount() : sum unreadCount across contacts
                                                    fx   markContactAsRead(String chatId) : set unreadCount to 0 for contact
                                                    fx   setTypingStatus(String chatId, bool isTyping, String userId) : cache typing user id per chat
                                                    fx   getTypingStatus(String chatId) : fetch typing user id
                                                    fx   addMessageReaction(String chatId, String messageId, String emoji, String userId) : persist reaction update on a message

                        notification_service.dart
                                            NotificationService (singleton)
                                                    v    FlutterLocalNotificationsPlugin _notificationsPlugin : platform notifier

                                                    fx   initialize() : configure Android notification settings
                                                    fx   showChatNotification({title, body, chatId}) : display high-priority chat notification with payload chatId
                                                    fx   cancelAllNotifications() : clear all scheduled/shown notifications

                profile_state.dart
                                            ProfileState (ChangeNotifier)
                                                    v    User? _currentUser : currently loaded user
                                                    v    UserPreferencesService _userService : persistence helper

                                                    P    ProfileState() : constructor triggers load
                                                    fx   _loadUserData() : fetch user from preferences and notify listeners
                                                    fx   refreshUser() : reload user data
                                                    fx   updateProfile(User user) : save user and notify listeners

                        


                                                



