// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get currentLanguage => 'English';

  @override
  String get pathGenerated => 'Path generated';

  @override
  String get pathLoop => 'Loop';

  @override
  String get pathSimple => 'Simple';

  @override
  String get start => 'Start';

  @override
  String get share => 'Share';

  @override
  String get toTheRun => 'To the run';

  @override
  String get pathPoint => 'Point';

  @override
  String get pathTotal => 'Total';

  @override
  String get pathTime => 'Duration';

  @override
  String get pointsCount => 'Points';

  @override
  String get guide => 'GUIDE';

  @override
  String get course => 'COURSE';

  @override
  String get enterDestination => 'Enter a destination';

  @override
  String shareMsg(String distance) {
    return 'My $distance km RunAway route generated with the RunAway app';
  }

  @override
  String get currentPosition => 'Current position';

  @override
  String get retrySmallRay => 'Try again with a smaller ray';

  @override
  String get noCoordinateServer => 'No coordinate received from the server';

  @override
  String get generationError => 'Error during the generation';

  @override
  String get disabledLocation => 'Location services are disabled.';

  @override
  String get deniedPermission => 'Location permissions are denied.';

  @override
  String get disabledAndDenied => 'Location permissions are permanently denied, we cannot request permission.';

  @override
  String get toTheRouteNavigation => 'Navigation to the stopped route';

  @override
  String get completedCourseNavigation => 'Navigation of the completed course';

  @override
  String get startingPoint => 'Starting point reached!';

  @override
  String get startingPointNavigation => 'Navigation to the starting point...';

  @override
  String get arrivedToStartingPoint => 'You have arrived at the starting point of the course!';

  @override
  String get later => 'Later';

  @override
  String get startCourse => 'Start the course';

  @override
  String get courseStarted => 'Navigation of the course started...';

  @override
  String get userAreStartingPoint => 'You are at the starting point of the course.';

  @override
  String get error => 'Error';

  @override
  String get routeCalculation => 'Calculation of the route to the course...';

  @override
  String get unableCalculateRoute => 'Unable to calculate the route to the course';

  @override
  String unableStartNavigation(Object error) {
    return 'Unable to start navigation: $error';
  }

  @override
  String get navigationServiceError => 'The navigation service returned false';

  @override
  String get calculationError => 'Error calculation route';

  @override
  String calculationRouteError(String error) {
    return 'Error calculation route: $error';
  }

  @override
  String get navigationInitializedError => 'Navigation error (service not initialized)';

  @override
  String get navigationError => 'Error of the navigation service';

  @override
  String get retry => 'Try again';

  @override
  String get navigationToCourse => 'Navigation to the course';

  @override
  String userToStartingPoint(String distance) {
    return 'You are $distance from the starting point.';
  }

  @override
  String get askUserChooseRoute => 'What do you want to do?';

  @override
  String get voiceInstructions => 'Navigation with voice instructions';

  @override
  String get cancel => 'Cancel';

  @override
  String get directPath => 'Direct path';

  @override
  String get guideMe => 'Guide me';

  @override
  String get readyToStart => 'Ready to start the navigation of the course';

  @override
  String get notAvailablePosition => 'User position or route not available';

  @override
  String get urbanization => 'Level of urbanization';

  @override
  String get terrain => 'Type of terrain';

  @override
  String get activity => 'Type of activity';

  @override
  String get distance => 'Distance';

  @override
  String get elevation => 'Elevation gain';

  @override
  String get generate => 'Generate';

  @override
  String get advancedOptions => 'Advanced options';

  @override
  String get loopCourse => 'Loop course';

  @override
  String get returnStartingPoint => 'Return to the starting point';

  @override
  String get avoidTraffic => 'Avoid traffic';

  @override
  String get quietStreets => 'Prioritize quiet streets';

  @override
  String get scenicRoute => 'Scenic route';

  @override
  String get prioritizeLandscapes => 'Prioritize beautiful landscapes';

  @override
  String get walking => 'Walk';

  @override
  String get running => 'Run';

  @override
  String get cycling => 'Cycle';

  @override
  String get nature => 'Nature';

  @override
  String get mixedUrbanization => 'Mixed';

  @override
  String get urban => 'Urban';

  @override
  String get flat => 'Flat';

  @override
  String get mixedTerrain => 'Mixed';

  @override
  String get hilly => 'Hilly';

  @override
  String get flatDesc => 'Flat land with little elevation gain';

  @override
  String get mixedTerrainDesc => 'Varied terrain with moderate elevation gain';

  @override
  String get hillyDesc => 'Land with a steep slope';

  @override
  String get natureDesc => 'Mainly in nature';

  @override
  String get mixedUrbanizationDesc => 'Mix city and nature';

  @override
  String get urbanDesc => 'Mainly in the city';

  @override
  String get arriveAtDestination => 'You arrive at your destination';

  @override
  String continueOn(int distance) {
    return 'Continue straight on ${distance}m';
  }

  @override
  String followPath(String distance) {
    return 'Follow the path for ${distance}km';
  }

  @override
  String get restrictedAccessTitle => 'Restricted access';

  @override
  String get notLoggedIn => 'You are not logged in';

  @override
  String get loginOrCreateAccountHint => 'To access this page, please log in or create an account.';

  @override
  String get logIn => 'Log in';

  @override
  String get createAccount => 'Create an account';

  @override
  String get needHelp => 'Need help? ';

  @override
  String get createAccountTitle => 'Ready for adventure?';

  @override
  String get createAccountSubtitle => 'Create your account to discover unique routes and start exploring new sporting horizons';

  @override
  String get emailHint => 'Email address';

  @override
  String get passwordHint => 'Password';

  @override
  String get confirmPasswordHint => 'Confirm password';

  @override
  String get passwordsDontMatchError => 'Passwords do not match';

  @override
  String get haveAccount => 'Have an account?';

  @override
  String get termsAndPrivacy => 'Terms & Privacy';

  @override
  String get continueForms => 'Continue';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get orDivider => 'OR';

  @override
  String get loginGreetingTitle => 'Great to see you back!';

  @override
  String get loginGreetingSubtitle => 'Sign in to your account to access all your data and pick up where you left off';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get createAccountQuestion => 'Create an account?';

  @override
  String get signUp => 'Sign up';

  @override
  String get appleLoginTodo => 'Apple login – To be implemented';

  @override
  String get googleLoginTodo => 'Google login – To be implemented';

  @override
  String get setupAccountTitle => 'Set up your account';

  @override
  String get onboardingInstruction => 'Please complete all the information presented below to create your account.';

  @override
  String get fullNameHint => 'John Doe';

  @override
  String get usernameHint => '@johndoe';

  @override
  String get complete => 'Complete';

  @override
  String get creatingProfile => 'Creating your profile...';

  @override
  String get fullNameRequired => 'Full name is required';

  @override
  String get fullNameMinLength => 'Name must be at least 2 characters';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get usernameMinLength => 'Username must be at least 3 characters';

  @override
  String get usernameInvalidChars => 'Only letters, numbers and _ are allowed';

  @override
  String imagePickError(Object error) {
    return 'Error selecting image: $error';
  }

  @override
  String get avatarUploadWarning => 'Profile created but avatar could not be uploaded. You can add it later.';

  @override
  String get emailInvalid => 'Invalid email address';

  @override
  String get passwordMinLength => 'At least 6 characters';

  @override
  String get currentGeneration => 'Current generation...';

  @override
  String get navigationPaused => 'Navigation paused';

  @override
  String get navigationResumed => 'Navigation resumed';

  @override
  String get time => 'Time';

  @override
  String get pace => 'Pace';

  @override
  String get speed => 'Speed';

  @override
  String get elevationGain => 'Gain';

  @override
  String get remaining => 'Remaining';

  @override
  String get progress => 'Progress';

  @override
  String get estimatedTime => 'Est. Time';

  @override
  String get updatingPhoto => 'Updating the photo…';

  @override
  String selectionError(String error) {
    return 'Error during selection: $error';
  }

  @override
  String get account => 'Account';

  @override
  String get defaultUserName => 'User';

  @override
  String get preferences => 'Preferences';

  @override
  String get notifications => 'Notifications';

  @override
  String get theme => 'Theme';

  @override
  String get enabled => 'Enabled';

  @override
  String get lightTheme => 'Light';

  @override
  String get selectPreferenceTheme => 'Select your preference';

  @override
  String get autoTheme => 'Auto';

  @override
  String get darkTheme => 'Dark';

  @override
  String get accountSection => 'Account';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get editProfileTodo => 'Profile editing – To implement';

  @override
  String get logoutTitle => 'Log out';

  @override
  String get logoutMessage => 'You’ll be signed out of Trailix, but all your saved data and preferences will remain secure';

  @override
  String get logoutConfirm => 'Log out';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountMessage => 'This will permanently delete your Trailix account as well as all saved routes and preferences, this action cannot be undone';

  @override
  String get deleteAccountWarning => 'This action cannot be undone';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAccountTodo => 'Account deletion – To implement';

  @override
  String get editPhoto => 'Edit the photo';

  @override
  String get availableLanguage => 'Available language';

  @override
  String get selectPreferenceLanguage => 'Select your preference';

  @override
  String get activityTitle => 'Activity';

  @override
  String get exportData => 'Export data';

  @override
  String get resetGoals => 'Reset goals';

  @override
  String get statisticsCalculation => 'Calculation of statistics...';

  @override
  String get loading => 'Loading...';

  @override
  String get createGoal => 'Create a goal';

  @override
  String get customGoal => 'Custom goal';

  @override
  String get createCustomGoal => 'Create a custom goal';

  @override
  String get goalsModels => 'Goals models';

  @override
  String get predefinedGoals => 'Choose from pre-defined goals';

  @override
  String get updatedGoal => 'Updated goal';

  @override
  String get createdGoal => 'Goal created';

  @override
  String get deleteGoalTitle => 'Delete goal';

  @override
  String get deleteGoalMessage => 'Are you sure you want to delete this goal?';

  @override
  String get removedGoal => 'Goal removed';

  @override
  String get goalsResetTitle => 'Reset the goals';

  @override
  String get goalsResetMessage => 'This action will remove all your goals. Are you sure?';

  @override
  String get reset => 'Reset';

  @override
  String get activityFilter => 'By activity';

  @override
  String get allFilter => 'All';

  @override
  String totalRoutes(int totalRoutes) {
    return '$totalRoutes routes';
  }

  @override
  String get emptyDataFilter => 'No data for this filter';

  @override
  String get byActivityFilter => 'Filter by activity';

  @override
  String get typeOfActivity => 'Choose the type of activity';

  @override
  String get allActivities => 'All activities';

  @override
  String get modifyGoal => 'Modify goal';

  @override
  String get newGoal => 'New goal';

  @override
  String get modify => 'Modify';

  @override
  String get create => 'Create';

  @override
  String get goalTitle => 'Goal title';

  @override
  String get titleValidator => 'You should enter a title';

  @override
  String get optionalDescription => 'Description (optional)';

  @override
  String get goalType => 'Goal type';

  @override
  String get optionalActivity => 'Activity (optional)';

  @override
  String get targetValue => 'Target value';

  @override
  String get targetValueValidator => 'Please enter a target value';

  @override
  String get positiveValueValidator => 'Please enter a positive value';

  @override
  String get optionalDeadline => 'Deadline (optional)';

  @override
  String get selectDate => 'Select a date';

  @override
  String get distanceType => 'km';

  @override
  String get routesType => 'routes';

  @override
  String get speedType => 'km/h';

  @override
  String get elevationType => 'm';

  @override
  String get goalTypeDistance => 'Monthly distance';

  @override
  String get goalTypeRoutes => 'Number of routes';

  @override
  String get goalTypeSpeed => 'Aver. speed';

  @override
  String get goalTypeElevation => 'Total elevation gain';

  @override
  String get monthlyRaceTitle => 'Monthly race';

  @override
  String get monthlyRaceMessage => '50km per month of running';

  @override
  String get monthlyRaceGoal => 'Run 50km per month';

  @override
  String get weeklyBikeTitle => 'Weekly bike';

  @override
  String get weeklyBikeMessage => '100km per week by bike';

  @override
  String get weeklyBikeGoal => 'Ride a bike for 100km per week';

  @override
  String get regularTripsTitle => 'Regular courses';

  @override
  String get regularTripsMessage => '10 courses per month';

  @override
  String get regularTripsGoal => 'Complete 10 courses per month';

  @override
  String get mountainChallengeTitle => 'Mountain Challenge';

  @override
  String get mountainChallengeMessage => '1000m of elevation gain per month';

  @override
  String get mountainChallengeGoal => 'Climb 1000m of elevation gain per month';

  @override
  String get averageSpeedTitle => 'Average speed';

  @override
  String get averageSpeedMessage => 'Maintain 12km/h of average';

  @override
  String get averageSpeedGoal => 'Maintain an average speed of 12km/h';

  @override
  String get personalGoals => 'Personal goals';

  @override
  String get add => 'Add';

  @override
  String get emptyDefinedGoals => 'You have no defined goals';

  @override
  String get pressToAdd => 'Press + to create one';

  @override
  String get personalRecords => 'Personal records';

  @override
  String get empryPersonalRecords => 'Complete courses to establish your records';

  @override
  String get overview => 'Overview';

  @override
  String get totalDistance => 'Total distance';

  @override
  String get totalTime => 'Total time';

  @override
  String get confirmRouteDeletionTitle => 'Confirm the deletion';

  @override
  String confirmRouteDeletionMessage(String routeName) {
    return 'Do you really want to delete the $routeName route?';
  }

  @override
  String get historic => 'Route';

  @override
  String get loadingError => 'Loading error';

  @override
  String get emptySavedRouteTitle => 'No route saved';

  @override
  String get emptySavedRouteMessage => 'Generate your first route from the homepage to see it appear here';

  @override
  String get generateRoute => 'Generate a route';

  @override
  String get route => 'Route';

  @override
  String get total => 'Total';

  @override
  String get unsynchronized => 'Unsync';

  @override
  String get synchronized => 'Sync';

  @override
  String get renameRoute => 'Rename';

  @override
  String get synchronizeRoute => 'Synchronize';

  @override
  String get deleteRoute => 'Delete';

  @override
  String get followRoute => 'Follow';

  @override
  String get imageUnavailable => 'Image unavailable';

  @override
  String get mapStyleTitle => 'Type of card';

  @override
  String get mapStyleSubtitle => 'Choose your style';

  @override
  String get mapStyleStreet => 'Street';

  @override
  String get mapStyleOutdoor => 'Outdoor';

  @override
  String get mapStyleLight => 'Light';

  @override
  String get mapStyleDark => 'Dark';

  @override
  String get mapStyleSatellite => 'Satellite';

  @override
  String get mapStyleHybrid => 'Hybrid';

  @override
  String get fullNameTitle => 'Full name';

  @override
  String get usernameTitle => 'Username';

  @override
  String get nonEditableUsername => 'The username cannot be modified';

  @override
  String get profileUpdated => 'Successfully updated profile';

  @override
  String get profileUpdateError => 'Error updating profile';

  @override
  String get contactUs => 'Contact us.';

  @override
  String get editGoal => 'Edit goal';

  @override
  String deadlineValid(String date) {
    return 'Valid until the $date';
  }

  @override
  String get download => 'Download';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving...';

  @override
  String get alreadySaved => 'Already saved';

  @override
  String get home => 'Home';

  @override
  String get resources => 'Resources';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get rateInStore => 'Rate in store';

  @override
  String get followOnX => 'Follow @Trailix';

  @override
  String get supportEmailSubject => 'Issue with your app';

  @override
  String get supportEmailBody => 'Hello Trailix Support,\n\nI\'m having trouble in the app.\nCould you please help me resolve this?\n\nThank you.';

  @override
  String get insufficientCreditsTitle => 'Insufficient credits';

  @override
  String insufficientCreditsDescription(int requiredCredits, String action, int availableCredits) {
    return 'You need $requiredCredits credit(s) to $action. You currently have $availableCredits credit(s).';
  }

  @override
  String get buyCredits => 'Buy credits';

  @override
  String get currentCredits => 'Current credits';

  @override
  String get availableCredits => 'Available credits';

  @override
  String get totalUsed => 'Total used';

  @override
  String get popular => 'Popular';

  @override
  String get buySelectedPlan => 'Buy this plan';

  @override
  String get selectPlan => 'Select a plan';

  @override
  String get purchaseSimulated => 'Purchase simulated';

  @override
  String get purchaseSimulatedDescription => 'In development mode, purchases are simulated. Do you want to simulate this purchase?';

  @override
  String get simulatePurchase => 'Simulate purchase';

  @override
  String get purchaseSuccess => 'Purchase successful!';

  @override
  String get transactionHistory => 'Transaction history';

  @override
  String get noTransactions => 'No transactions yet';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get daysAgo => 'days';

  @override
  String get ok => 'OK';

  @override
  String get creditUsageSuccess => 'Credits used successfully';

  @override
  String get routeGenerationWithCredits => '1 credit will be used to generate this route';

  @override
  String get creditsRequiredForGeneration => 'Route generation (1 credit)';

  @override
  String get manageCredits => 'Manage my credits';

  @override
  String get freeCreditsWelcome => '🎉 Welcome! You have received 3 free credits to start';

  @override
  String creditsLeft(int count) {
    return '$count credit(s) left';
  }

  @override
  String get elevationRange => 'Elevation range';

  @override
  String get minElevation => 'Minimum elevation';

  @override
  String get maxElevation => 'Maximum elevation';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get maxIncline => 'Maximum incline';

  @override
  String get waypointsCount => 'Waypoints';

  @override
  String get points => 'pts';

  @override
  String get surfacePreference => 'Surface';

  @override
  String get naturalPaths => 'Natural paths';

  @override
  String get pavedRoads => 'Paved roads';

  @override
  String get mixed => 'Mixed';

  @override
  String get avoidHighways => 'Avoid highways';

  @override
  String get avoidMajorRoads => 'Avoid major roads';

  @override
  String get prioritizeParks => 'Prioritize parks';

  @override
  String get preferGreenSpaces => 'Prefer green spaces';

  @override
  String get elevationLoss => 'Elevation loss';

  @override
  String get duration => 'Duration';

  @override
  String get calories => 'Calories';

  @override
  String get scenic => 'Scenic';

  @override
  String get maxSlope => 'Max slope';

  @override
  String get highlights => 'Highlights';

  @override
  String get surfaces => 'Surfaces';

  @override
  String get easyDifficultyLevel => 'Easy';

  @override
  String get moderateDifficultyLevel => 'Moderate';

  @override
  String get hardDifficultyLevel => 'Hard';

  @override
  String get expertDifficultyLevel => 'Expert';

  @override
  String get asphaltSurfaceTitle => 'Asphalt';

  @override
  String get asphaltSurfaceDesc => 'Prioritizes paved roads and sidewalks';

  @override
  String get mixedSurfaceTitle => 'Mixed';

  @override
  String get mixedSurfaceDesc => 'Mix of roads and paths according to the route';

  @override
  String get naturalSurfaceTitle => 'Natural';

  @override
  String get naturalSurfaceDesc => 'Prioritizes natural trails and paths';

  @override
  String get searchAdress => 'Search for an address...';

  @override
  String get chooseName => 'Choose a name';

  @override
  String get canModifyLater => 'You can modify it later';

  @override
  String get routeName => 'Route name';

  @override
  String get limitReachedGenerations => 'Limit reached';

  @override
  String get exhaustedGenerations => 'Exhausted generations';

  @override
  String get remainingLimitGenerations => 'Remaining limit';

  @override
  String remainingGenerationsLabel(int remainingGenerations) {
    String _temp0 = intl.Intl.pluralLogic(
      remainingGenerations,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$remainingGenerations free generation$_temp0';
  }

  @override
  String get freeGenerations => 'Free generations';

  @override
  String get exhaustedFreeGenerations => 'Exhausted free generations';

  @override
  String get exhaustedCredits => 'Credits exhausted';

  @override
  String get authForMoreGenerations => 'Create a free account for more generations';

  @override
  String get createFreeAccount => 'Create a free account';

  @override
  String get exportRouteTitle => 'Export the route';

  @override
  String get exportRouteDesc => 'Choose the export format';

  @override
  String get generateInProgress => 'Generation of the route...';

  @override
  String get emptyRouteForSave => 'No route to save';

  @override
  String get connectionError => 'Connection error';

  @override
  String get notAvailableMap => 'Map not available';

  @override
  String get missingRouteSettings => 'Missing route settings';

  @override
  String get savedRoute => 'Saved route';

  @override
  String get loginRequiredTitle => 'Login required';

  @override
  String get loginRequiredDesc => 'You must be logged in to save your courses';

  @override
  String get reallyContinueTitle => 'Do you really want to continue?';

  @override
  String get reallyContinueDesc => 'This action will delete the previously generated route, it will then be unrecoverable!';

  @override
  String get generationEmptyLocation => 'No position available for the generation';

  @override
  String get unableLaunchGeneration => 'Unable to launch the generation';

  @override
  String get invalidParameters => 'Invalid parameters';

  @override
  String get locationInProgress => 'Location...';

  @override
  String get searchingPosition => 'Search for your position';

  @override
  String get trackingError => 'Tracking error';

  @override
  String get enterAuthDetails => 'Enter your details';

  @override
  String get enterPassword => 'Enter a password';

  @override
  String get continueWithEmail => 'Continue with email';

  @override
  String get passwordVeryWeak => 'Very weak';

  @override
  String get passwordWeak => 'Weak';

  @override
  String get passwordFair => 'Fair';

  @override
  String get passwordGood => 'Good';

  @override
  String get passwordStrong => 'Strong';

  @override
  String resetEmail(String email) {
    return 'Reset email sent to $email';
  }

  @override
  String get requiredPassword => 'Required password';

  @override
  String requiredCountCharacters(int count) {
    return 'At least $count characters required';
  }

  @override
  String get requiredCapitalLetter => 'At least one capital letter required';

  @override
  String get requiredMinusculeLetter => 'At least one minuscule required';

  @override
  String get requiredDigit => 'At least one required digit';

  @override
  String get requiredSymbol => 'At least one required symbol';

  @override
  String minimumCountCharacters(int count) {
    return 'Minimum $count characters';
  }

  @override
  String get oneCapitalLetter => 'One capital letter';

  @override
  String get oneMinusculeLetter => 'One minuscule letter';

  @override
  String get oneDigit => 'One digit';

  @override
  String get oneSymbol => 'One symbol';

  @override
  String get successEmailSentBack => 'Confirmation email sent back successfully';

  @override
  String get checkEmail => 'Check your email';

  @override
  String successSentConfirmationLink(String email) {
    return 'We have sent a verification code to $email';
  }

  @override
  String get resendCode => 'Resend the code';

  @override
  String resendCodeInDelay(int count) {
    return 'Resend in ${count}s';
  }

  @override
  String get loginBack => 'Back to login';

  @override
  String get requiredEmail => 'Required email';

  @override
  String get receiveResetLink => 'Enter your email address to receive a reset link';

  @override
  String get send => 'Send';

  @override
  String get byDefault => 'By default';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get desiredSelectionMode => 'Before continuing, please choose the desired selection mode';

  @override
  String get cameraMode => 'Camera';

  @override
  String get galleryMode => 'Gallery';

  @override
  String get successUpdatedProfile => 'Successfully updated profile';

  @override
  String couldNotLaunchUrl(String url) {
    return 'Could not launch $url';
  }

  @override
  String get couldNotLaunchEmailApp => 'Could not launch email app';

  @override
  String get userBalance => 'Your balance';

  @override
  String get purchasedCredits => 'Purchased';

  @override
  String get usedCredits => 'Used';

  @override
  String get purchaseCreditsTitle => 'Purchased credits';

  @override
  String get usageCreditsTitle => 'Credit to generate a route';

  @override
  String get bonusCreditsTitle => 'Free welcome credits';

  @override
  String get refundCreditsTitle => 'Restored credits';

  @override
  String get notAvailablePlans => 'Plans not available';

  @override
  String get missingTransactionID => 'Missing transaction ID';

  @override
  String get purchaseCanceled => 'Purchase canceled';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get duringPaymentError => 'Error during payment';

  @override
  String get networkException => 'Connection problem. Please try again.';

  @override
  String get retryNotAvailablePlans => 'Selected plan not available. Please try again.';

  @override
  String get systemIssueDetectedTitle => 'System issue detected';

  @override
  String get systemIssueDetectedSubtitle => 'A system issue has been detected. This may happen if previous purchases did not complete correctly.';

  @override
  String get systemIssueDetectedDesc => 'Restart the application and try again';

  @override
  String get close => 'Close';

  @override
  String get cleaningDone => 'Cleaning done. Try again now.';

  @override
  String cleaningError(String error) {
    return 'Error while cleaning: $error';
  }

  @override
  String get cleaning => 'Cleaning';

  @override
  String get creditPlanModalTitle => 'Stock up on credits to live new adventures!';

  @override
  String get creditPlanModalSubtitle => 'Choose your favorite package, then click here to start exploring!';

  @override
  String get creditPlanModalWarning => 'Payment debited upon confirmation of purchase. Credits are non-refundable and valid only in the application.';

  @override
  String get refresh => 'Refresh';

  @override
  String get successRouteDeleted => 'Route successfully deleted';

  @override
  String get errorRouteDeleted => 'Error while deleting';

  @override
  String get displayRouteError => 'Error during the display of the course';

  @override
  String get routeNameUpdateException => 'The name cannot be empty';

  @override
  String get routeNameUpdateExceptionMinCharacters => 'The name must contain at least 2 characters';

  @override
  String get routeNameUpdateExceptionCountCharacters => 'The name cannot exceed 50 characters';

  @override
  String get routeNameUpdateExceptionForbiddenCharacters => 'The name contains forbidden characters';

  @override
  String get routeNameUpdateDone => 'Update done';

  @override
  String formatRouteExport(String format) {
    return 'Route exported in $format';
  }

  @override
  String routeExportError(String error) {
    return 'Error during export: $error';
  }

  @override
  String get updateRouteNameTitle => 'Update';

  @override
  String get updateRouteNameSubtitle => 'Choose a new name';

  @override
  String get updateRouteNameHint => 'Digestive walk';

  @override
  String get initializationError => 'Initialization error';

  @override
  String get gpxFormatName => 'Garmin / Komoot...';

  @override
  String get gpxFormatDescription => 'To export in GPX File';

  @override
  String get kmlFormatName => 'Google Maps / Earth...';

  @override
  String get kmlFormatDescription => 'To export in KML File';

  @override
  String get routeExportedFrom => 'Route exported from Trailix';

  @override
  String routeDescription(String activityType, String distance) {
    return '$activityType route of ${distance}km generated by Trailix';
  }

  @override
  String routeDistanceLabel(String distance) {
    return 'Route of ${distance}km';
  }

  @override
  String get endPoint => 'End';

  @override
  String get emptyRouteForExport => 'No route to export';

  @override
  String get serverErrorRetry => 'Server error. Please try again later.';

  @override
  String get genericErrorRetry => 'An error occurred. Please try again.';

  @override
  String get invalidRequest => 'Invalid request';

  @override
  String get serviceUnavailable => 'Service temporarily unavailable. Try again in a few minutes.';

  @override
  String get timeoutError => 'Timeout exceeded. Check your connection.';

  @override
  String get unexpectedServerError => 'Unexpected server error';

  @override
  String serverErrorCode(int statusCode) {
    return 'Server error ($statusCode)';
  }

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get timeoutRetry => 'Timeout exceeded. Try again.';

  @override
  String get invalidServerResponse => 'Invalid server response';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get userCanceledConnection => 'Connection canceled by user';

  @override
  String get pleaseReconnect => 'Please reconnect';

  @override
  String get profileManagementError => 'Error managing user profile';

  @override
  String get connectionProblem => 'Connection problem. Check your internet connection';

  @override
  String get authenticationError => 'An authentication error occurred';

  @override
  String get passwordMustRequired => 'The password must contain at least 8 characters with uppercase, lowercase, digit and symbol';

  @override
  String get passwordTooShort => 'The password must contain at least 8 characters';

  @override
  String get notConfirmedEmail => 'Email not confirmed. Check your mailbox.';

  @override
  String get confirmEmailBeforeLogin => 'Please confirm your email before logging in';

  @override
  String get emailAlreadyUsed => 'An account already exists with this email';

  @override
  String get passwordTooSimple => 'The password does not meet the security requirements';

  @override
  String get expiredSession => 'Session expired. Please reconnect';

  @override
  String get savingProfileError => 'Error while saving the profile';

  @override
  String get timeAgoAtMoment => 'at the moment';

  @override
  String get timeAgoFallback => 'recent';

  @override
  String timaAgoSecondes(int difference) {
    return 'there are $difference s';
  }

  @override
  String timaAgoMinutes(int difference) {
    return 'there are $difference min';
  }

  @override
  String timaAgoHours(int difference) {
    return 'there are $difference h';
  }

  @override
  String daysAgoLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'there are $days day$_temp0';
  }

  @override
  String routeGenerateName(int count) {
    return 'Route n°$count';
  }

  @override
  String routeGenerateDesc(String date) {
    return 'Generated on the $date';
  }

  @override
  String get notEmailFound => 'Email address not found';

  @override
  String get resetPasswordImpossible => 'Unable to reset password';

  @override
  String get enterVerificationCode => 'Enter the 6-digit code';

  @override
  String verificationCodeSentTo(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get verify => 'Verify';

  @override
  String get invalidCode => 'Invalid or expired code';

  @override
  String get codeRequired => 'Please enter the verification code';

  @override
  String get codeMustBe6Digits => 'Code must be 6 digits';

  @override
  String get orUseEmailLink => 'Or use the link in your email';

  @override
  String get abuseConnection => 'Abuse of connection';

  @override
  String get passwordResetSuccess => 'Password Updated!';

  @override
  String get passwordResetSuccessDesc => 'Your password has been successfully updated. You can now log in with your new password.';

  @override
  String get saveRoutesTitle => 'Save your routes';

  @override
  String get saveRoutesSubtitle => 'Keep your favorite routes with automatic photos';

  @override
  String get customGoalsTitle => 'Custom goals';

  @override
  String get customGoalsSubtitle => 'Create your goals for distance, speed and time';

  @override
  String get exportRoutesTitle => 'Export of your routes';

  @override
  String get exportRoutesSubtitle => 'Export your routes in GPX or KML to your favorite apps';

  @override
  String get alreadyHaveAnAccount => 'I have an account';

  @override
  String get conversionTitleRouteGenerated => 'Great route! 🎉';

  @override
  String get conversionTitleActivityViewed => 'Ready for your goals? 📊';

  @override
  String get conversionTitleMultipleRoutes => 'You love exploring! 🗺️';

  @override
  String get conversionTitleManualTest => 'Modal test! 🧪';

  @override
  String get conversionTitleDefault => 'Take it to the next level! 🚀';

  @override
  String get conversionSubtitleRouteGenerated => 'Save this route and track your performance with a free account.';

  @override
  String get conversionSubtitleActivityViewed => 'Create personalized goals and track your records.';

  @override
  String get conversionSubtitleMultipleRoutes => 'Save all your favorite routes and export them as GPX.';

  @override
  String get conversionSubtitleManualTest => 'Modal triggered manually for testing - all features await you!';

  @override
  String get conversionSubtitleDefault => 'Unlock saving, goals, and performance tracking.';

  @override
  String get enterEmailToReset => 'Enter your email address to receive a reset code';

  @override
  String get enterNewPassword => 'Enter new password';

  @override
  String get createNewPassword => 'Create a strong new password';

  @override
  String get newPasswordHint => 'New password';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String get updatePassword => 'Update password';

  @override
  String get passwordMustBeDifferent => 'The new password must be different from the old one';

  @override
  String get verfyPasswordInProgress => 'Verification of the code...';

  @override
  String get requestNewCode => 'Request a new code';

  @override
  String get requiredField => 'Required field';

  @override
  String get enterValidNumber => 'Please enter a valid number';

  @override
  String greaterValue(String min) {
    return 'The value must be greater than or equal to $min';
  }

  @override
  String lessValue(String max) {
    return 'The value must be less than or equal to $max';
  }

  @override
  String get userSummary => 'Your summary';

  @override
  String get noPositionEnable => 'GPS position not available. Check your settings.';

  @override
  String get checkNetwork => 'Please check your internet connection to access this feature';

  @override
  String get processing => 'Processing...';

  @override
  String get purchaseInProgress => 'Current purchase...';

  @override
  String get testEnvironmentWarning => 'Test environment - Simulated purchase';

  @override
  String get purchaseAlreadyInProgress => 'A purchase is already in progress';

  @override
  String get purschaseTimeout => 'Timeout during the purchase';

  @override
  String get purschaseImpossible => 'Unable to launch the purchase process';

  @override
  String get disabledInAppPurchase => 'In-app purchases are not available';

  @override
  String notFoundProduct(String id) {
    return 'Product $id not found in the store';
  }

  @override
  String errorRestoredPurchase(String error) {
    return 'Purchase processing error restored: $error';
  }

  @override
  String get creditVerificationFailed => 'Unable to check your credits';

  @override
  String get routeGenerationNetworkError => 'Connection problem. Check your internet and try again.';

  @override
  String get routeGenerationProtected => 'Your credits are protected, they will only be debited in case of a successful generation';

  @override
  String get creditConsumptionAfterSuccess => 'Successful generation! 1 credit used';

  @override
  String get sessionExpiredLogin => 'Session expired. Please log in again.';

  @override
  String get offlineGenerationError => 'Check your internet connection to generate a route.';

  @override
  String get validationError => 'Validation error';

  @override
  String get accessDenied => 'Access denied';

  @override
  String get resourceNotFound => 'Resource not found';

  @override
  String get tooManyRequests => 'Too many requests, please wait';

  @override
  String get internalServerError => 'Internal server error';

  @override
  String get badGateway => 'Bad gateway';

  @override
  String get gatewayTimeout => 'Gateway timeout';

  @override
  String get signupDisabled => 'Registration temporarily disabled';

  @override
  String get userNotFound => 'User not found';

  @override
  String get sessionExpired => 'Session expired, please log in again';

  @override
  String get duplicateEntry => 'This entry already exists';

  @override
  String get databaseError => 'Database error';

  @override
  String get storageError => 'Storage error';

  @override
  String get serverFunctionError => 'Server function error';

  @override
  String get fileAccessError => 'File access error';

  @override
  String get routeGenerationFailed => 'Route generation failed';

  @override
  String get locationServicesDisabled => 'Location services disabled';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationPermissionPermanentlyDenied => 'Location permission permanently denied';

  @override
  String get insufficientCredits => 'Insufficient credits';

  @override
  String get purchaseFailed => 'Purchase failed';

  @override
  String get purchaseValidationFailed => 'Purchase validation failed';

  @override
  String get notificationPermissionDenied => 'Notification permission denied';

  @override
  String get shareError => 'Share error';

  @override
  String get cacheError => 'Cache error';

  @override
  String get configurationError => 'Configuration error';

  @override
  String get serviceInitializationError => 'Service initialization error';

  @override
  String get noRouteFound => 'No route found';

  @override
  String get routeCalculationError => 'Route calculation error';

  @override
  String get mapLoadingError => 'Map loading error';

  @override
  String get coordinatesInvalid => 'Invalid coordinates';

  @override
  String get exportError => 'Export error';

  @override
  String get importError => 'Import error';

  @override
  String get syncError => 'Synchronization error';

  @override
  String get offlineMode => 'Offline mode active';

  @override
  String get connectionRestored => 'Connection restored';

  @override
  String get retryAction => 'Retry';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get closeAction => 'Close';

  @override
  String get errorDialogTitle => 'Error';

  @override
  String get warningDialogTitle => 'Warning';

  @override
  String get infoDialogTitle => 'Information';

  @override
  String get errorDetails => 'Error details';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String errorCode(String code) {
    return 'Error code: $code';
  }

  @override
  String errorTime(String time) {
    return 'Time: $time';
  }

  @override
  String get reportError => 'Report error';

  @override
  String get errorReported => 'Error reported successfully';
}
