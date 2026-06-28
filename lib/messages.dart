class Messages {
  // ─── GENERIC ───────────────────────────────────────────────
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
  static const String failedToLoad = 'Failed to load data. Please try again.';
  static const String userNotAuthenticated = 'User is not authenticated. Cannot upload image.';
  static const String ok = 'OK';
  static const String cancel = 'CANCEL';
  static const String later = 'MAYBE LATER';

  // ─── AUTH (login / register) ───────────────────────────────
  static const String invalidEmailOrPassword = 'Invalid email or password';
  static const String emailAlreadyExists = 'An account with this email already exists.';
  static const String weakPassword = 'Password must be at least 8 characters with uppercase, lowercase, and a number.';
  static const String passwordTooShort = 'Password must be at least 8 characters long.';
  static const String authFailed = 'Authentication failed. Please try again.';

  static const String passwordStrengthTooShort = 'TOO SHORT (MIN 8 CHARS)';
  static const String passwordStrengthWeak = 'WEAK - ADD UPPERCASE, LOWERCASE & DIGIT';
  static const String passwordStrengthGood = 'GOOD - ADD SPECIAL CHAR FOR STRONG';
  static const String passwordStrengthSecure = 'SECURE PASSWORD';
  static const String passwordStrengthHint = 'MINIMUM 8 CHARACTERS';

  static const String loginTitle = 'ENTER THE VOID';
  static const String loginButton = 'LOGIN';
  static const String registerTitle = 'INITIALIZE';
  static const String registerSubtitle = 'JOIN THE ALIGNMENT PROTOCOL.';
  static const String registerButton = 'CREATE ACCOUNT';
  static const String signUpPrompt = 'NEW HERE? INITIALIZE PROFILE';
  static const String signOut = 'Sign Out';
  static const String consentAgeCheck = 'I confirm that I am at least 18 (eighteen) years of age.';
  static const String consentTerms = 'I have read and agree to the ';
  static const String termsLink = 'Terms of Service';
  static const String consentPrivacy = 'I have read and agree to the ';
  static const String privacyLink = 'Privacy Policy';
  static const String consentGuidelines = 'I agree to the ';
  static const String guidelinesLink = 'Community Guidelines';
  static const String consentDataProcessing = 'I consent to the collection, storage, and processing of my personal data as described in the Privacy Policy.';
  static const String mustAcceptAll = 'Please accept all consent requirements to create an account.';

  // ─── ONBOARDING ────────────────────────────────────────────
  static const String pleaseUploadImage = 'Please upload at least one image';
  static const String pleaseEnterDob = 'Please enter your date of birth';
  static const String moderationRejected = 'Your inputs contain inappropriate language or restricted handles. Please revise them.';
  static const String imageRejectedSafety = 'Image rejected by safety filters. Please upload a different photo.';
  static const String serverRejectedProfile = 'Server rejected profile data';
  static const String errorLoadingOptions = 'Error loading options.';
  static const String uploadReturnedNoUrl = 'Upload returned no URL';

  static const String stepImages = 'Show your face';
  static const String stepImagesHint = 'Upload up to 6 photos. The first one will be your main profile picture.';
  static const String stepInterests = 'What are you into?';
  static const String stepInterestsHint = 'Pick up to 5 interests to help us find better alignments.';
  static const String stepDetails = 'The Details';
  static const String stepLifestyle = 'Lifestyle';
  static const String stepLifestyleHint = 'Help others know your vibe.';
  static const String stepExpectations = 'I\'m looking for...';
  static const String stepDob = 'When is your birthday?';
  static const String stepGender = 'I identify as...';
  static const String stepName = 'First Name';
  static const String stepLastName = 'Last Name (Optional)';
  static const String minAgeNotice = 'You must be at least 18 years old to use Duva.';
  static const String selectDate = 'Select Date';

  static const String checkingOverlay = 'AI Checking...';
  static const String rejectedOverlay = 'NSFW';
  static const String nextButton = 'NEXT';
  static const String letsGoButton = 'LET\'S GO';

  // ─── EXPLORE / SWIPE ───────────────────────────────────────
  static const String rewindPaywall = 'Upgrade to Duva Black to rewind!';
  static const String cannotRewindMatch = 'Cannot rewind an alignment.';
  static const String swipeLimitTitle = 'Daily Swipes Exhausted';
  static const String swipeLimitBody = 'You\'ve used all your free swipes for today. Upgrade to Duva Black for unlimited swipes.';
  static const String getDuvaBlack = 'GET DUVA BLACK';
  static const String comeBackTomorrow = 'Come back tomorrow';
  static const String alignmentSecured = 'ALIGNMENT SECURED';
  static const String outOfSuperlikesTitle = 'OUT OF SUPER ALIGNMENTS';
  static const String outOfSuperlikesBody = 'Stand out from the void. Super alignments are 3x more likely to result in a match.';
  static const String superlikePurchase = 'Processing ₹300 payment for 10 Superlikes...';
  static const String getSuperlikes = 'GET 10 FOR ₹300';
  static const String emptyPoolTitle = 'Scanning the Void';
  static const String emptyPoolBody = 'No profiles match your advanced filters.';
  static const String forceRescan = 'FORCE RESCAN';

  static const String alignLabel = 'ALIGN';
  static const String passLabel = 'PASS';
  static const String superLabel = 'SUPER';

  // ─── MODERATION / REPORT / BLOCK ────────────────────────────
  static const String blockUser = 'Unmatch & Block %s';
  static const String blockHint = 'They won\'t know you blocked them.';
  static const String reportUser = 'Report %s';
  static const String reportHint = 'Report inappropriate behavior or fake profiles.';
  static const String reportTitle = 'Why are you reporting this profile?';
  static const String profileRemoved = 'Profile removed securely.';

  // ─── EDIT PROFILE ───────────────────────────────────────────
  static const String maxPhotosReached = 'Maximum %d photos allowed.';
  static const String imageRejectedSafetyShort = 'Image rejected by safety filters.';
  static const String needAtLeastOnePhoto = 'You must have at least one profile photo.';
  static const String waitForPhotoCheck = 'Please wait for photos to finish checking.';
  static const String profanityDetected = 'Your profile contains inappropriate language or prohibited handles. Please keep it respectful.';
  static const String noValidImagesToSave = 'No valid images to save.';
  static const String unableToGenerateBio = 'Failed to generate bio. Try again later.';

  static const String editProfileTitle = 'EDIT PROFILE';
  static const String saveButton = 'SAVE';
  static const String saveChanges = 'SAVE CHANGES';
  static const String yourPhotos = 'YOUR PHOTOS';
  static const String photoReorderHint = 'Long press and drag to reorder your photos. Your first photo is your main identity.';
  static const String yourDateBid = 'YOUR DATE BID';
  static const String dateBidHint = 'e.g., Coffee at 4PM';
  static const String personalInfo = 'PERSONAL INFO';
  static const String lifestyle = 'LIFESTYLE';
  static const String aboutYou = 'ABOUT YOU';
  static const String bioLabel = 'Bio';
  static const String bioHint = 'A little bit about me...';
  static const String workLabel = 'Work';
  static const String workHint = 'Job Title / Company';
  static const String weightHint = 'e.g. 70';
  static const String weightUnit = 'kg';
  static const String aiSuggestions = 'AI SUGGESTIONS';
  static const String generateBio = 'Generate Bio with AI';
  static const String generatingBio = 'Generating...';
  static const String bioCooldown = 'Bio generation available in %d day(s)';
  static const String mainBadge = 'MAIN';
  static const String editInterests = 'EDIT INTERESTS';
  static const String yourInterests = 'YOUR INTERESTS';
  static const String selectUpTo5 = 'Select up to 5 interests.';
  static const String selectGender = 'Select Gender';
  static const String selectLabel = 'Select';

  // ─── CHAT ──────────────────────────────────────────────────
  static const String failedToSendMessage = 'Failed to send message';
  static const String noMessagesYet = 'No messages yet. Send a message to break the ice.';
  static const String startAlignment = 'Start the Alignment';
  static const String aiGeneratingIcebreakers = '✨ AI generating icebreakers...';
  static const String chatHint = 'Type a message...';
  static const String aiSuggestionsLabel = 'AI SUGGESTIONS';

  // ─── MATCHES ───────────────────────────────────────────────
  static const String matchesTitle = 'MATCHES';
  static const String matchesEmpty = 'No Alignments Yet';
  static const String matchesEmptyBody = 'Keep exploring the pool to find your match.';
  static const String newAlignments = 'New Alignments';
  static const String messagesSection = 'Messages';
  static const String matchedRecently = 'Matched recently! Say hi.';
  static const String matchDefaultName = 'Match';

  // ─── NOTIFICATIONS ─────────────────────────────────────────
  static const String notificationsTitle = 'NOTIFICATIONS';
  static const String markRead = 'MARK READ';
  static const String notificationsEmpty = 'The Void is Quiet';
  static const String notificationsEmptyBody = 'No new notifications right now.';
  static const String unlockPremiumAdmirers = 'Unlock Premium to see admirers!';
  static const String notificationDefaultTitle = 'Notification';

  // ─── ADMIRERS ──────────────────────────────────────────────
  static const String admirersTitle = 'ADMIRERS';
  static const String admirersEmpty = 'No Admirers Yet';
  static const String admirersEmptyBody = 'Keep swiping. Your alignments are out there.';
  static const String admirersPaywallTitle = 'Upgrade to Duva Black';
  static const String admirersPaywallBody = 'See who already liked you and match instantly.';
  static const String unlockAdmirers = 'Unlock Duva Black to reveal their photos & match!';
  static const String admirerSecret = 'Secret';
  static const String admirerNearby = 'Nearby';

  // ─── PREFERENCES ───────────────────────────────────────────
  static const String preferencesTitle = 'DISCOVERY';
  static const String ageRange = 'AGE RANGE';
  static const String maxDistance = 'MAXIMUM DISTANCE';
  static const String showMe = 'SHOW ME';
  static const String mustHaveInterests = 'MUST HAVE INTERESTS (OPTIONAL)';
  static const String applyFilters = 'APPLY FILTERS';
  static const String failedToSavePrefs = 'Failed to save settings.';

  // ─── PREMIUM ───────────────────────────────────────────────
  static const String premiumTitle = 'DUVA BLACK';
  static const String premiumSubtitle = 'Elevate your alignment.';
  static const String premiumSeeLikes = 'See Who Likes You';
  static const String premiumSeeLikesDesc = 'Unlock the Admirers Lounge.';
  static const String premiumRewinds = 'Unlimited Rewinds';
  static const String premiumRewindsDesc = 'Undo accidental passes instantly.';
  static const String premiumReadReceipts = 'Read Receipts';
  static const String premiumReadReceiptsDesc = 'Know when they read your messages.';
  static const String premiumFilters = 'Advanced Filters';
  static const String premiumFiltersDesc = 'Filter by height, zodiac & lifestyle.';
  static const String premiumUnlimited = 'Infinite Alignments';
  static const String premiumUnlimitedDesc = 'Swipe without daily limits.';
  static const String oneMonth = '1 Month';
  static const String threeMonths = '3 Months';
  static const String savePercent = 'SAVE 33%';
  static const String billedTotal = 'billed total';
  static const String continuePayment = 'CONTINUE WITH %s';
  static const String initializingGateway = 'Initializing gateway for %s%s...';

  // ─── PROFILE ───────────────────────────────────────────────
  static const String profileTitle = 'PROFILE';
  static const String myProfile = 'MY PROFILE';
  static const String profileNotFound = 'Profile not found.';
  static const String profileNotLoggedIn = 'User is not logged in.';
  static const String couldNotLoadProfile = 'Could not load profile. Have you completed onboarding?';
  static const String premiumBadge = 'BLACK';
  static const String myActiveDateBid = 'MY ACTIVE DATE BID';
  static const String profileLifestyle = 'LIFESTYLE';
  static const String aboutMe = 'ABOUT ME';
  static const String lookingFor = 'LOOKING FOR';
  static const String interests = 'INTERESTS';
  static const String profileComplete = 'Profile Complete!';
  static const String profilePercent = '%s% Complete';
  static const String fillProfile = 'FILL';
  static const String noBioYet = 'No bio written yet.';
  static const String tonightsBid = 'TONIGHT\'S BID';
  static const String unknownLocation = 'Unknown Location';
  static const String unknownUser = 'Unknown';
  static const String activeNow = 'Active Now';
  static const String hibernating = 'Hibernating';
  static const String recently = 'Recently';

  // ─── SETTINGS ──────────────────────────────────────────────
  static const String settingsTitle = 'SETTINGS';
  static const String appearance = 'APPEARANCE';
  static const String midnightGlass = 'Midnight Glass Mode';
  static const String account = 'ACCOUNT';
  static const String emailAddress = 'Email Address';
  static const String privacyPolicy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String safetyGuidelines = 'Safety Guidelines';
  static const String cookiePolicy = 'Cookie Policy';
  static const String privacyAndSecurity = 'Privacy & Security';
  static const String requestDataExport = 'Request Data Export';
  static const String exportLinkSent = 'Export link sent to email.';
  static const String dangerZone = 'DANGER ZONE';
  static const String deleteAccount = 'Delete Account';
  static const String deleteAccountTitle = 'Delete Account?';
  static const String deleteAccountBody = 'This action is permanent and cannot be undone. All your alignments, messages, and data will be wiped from the void.';
  static const String deleteConfirm = 'DELETE';
  static const String deleteFailed = 'Failed to delete account. Please try again.';
  static const String reauthRequired = 'Please re-authenticate before deleting your account. Sign out and sign back in.';

  // ─── UPLOAD ────────────────────────────────────────────────
  static const String cloudflareUploadFailed = 'Cloudflare Upload Failed';
}
