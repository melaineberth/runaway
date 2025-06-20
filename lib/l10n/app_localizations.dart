import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// Headline or toast shown once a route has been successfully generated.
  ///
  /// In en, this message translates to:
  /// **'Path generated'**
  String get pathGenerated;

  /// Toggle / chip label for selecting a circular (loop) route.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get pathLoop;

  /// Toggle / chip label for selecting a simple (out-and-back or point-to-point) route.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get pathSimple;

  /// Label for the primary action button that begins the workout or navigation.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Button text for sharing the generated route with others.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Navigation button that takes the user to the live run screen.
  ///
  /// In en, this message translates to:
  /// **'To the run'**
  String get toTheRun;

  /// Metric label indicating a single waypoint or checkpoint in the route details.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get pathPoint;

  /// Metric label denoting the aggregate distance of the route.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get pathTotal;

  /// Metric label showing the estimated time required to complete the route.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get pathTime;

  /// Metric label for the total number of waypoints/checkpoints in the generated route.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsCount;

  /// Section header for guidance or instructional content within the UI.
  ///
  /// In en, this message translates to:
  /// **'GUIDE'**
  String get guide;

  /// Section header for the route/course overview.
  ///
  /// In en, this message translates to:
  /// **'COURSE'**
  String get course;

  /// Placeholder text in a search field prompting the user to type the destination address or landmark.
  ///
  /// In en, this message translates to:
  /// **'Enter a destination'**
  String get enterDestination;

  /// No description provided for @shareMsg.
  ///
  /// In en, this message translates to:
  /// **'My {distance} km RunAway route generated with the RunAway app'**
  String shareMsg(String distance);

  /// No description provided for @currentPosition.
  ///
  /// In en, this message translates to:
  /// **'Current position'**
  String get currentPosition;

  /// No description provided for @retrySmallRay.
  ///
  /// In en, this message translates to:
  /// **'Try again with a smaller ray'**
  String get retrySmallRay;

  /// No description provided for @noCoordinateServer.
  ///
  /// In en, this message translates to:
  /// **'No coordinate received from the server'**
  String get noCoordinateServer;

  /// No description provided for @generationError.
  ///
  /// In en, this message translates to:
  /// **'Error during the generation'**
  String get generationError;

  /// No description provided for @disabledLocation.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get disabledLocation;

  /// No description provided for @deniedPermission.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied.'**
  String get deniedPermission;

  /// No description provided for @disabledAndDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied, we cannot request permission.'**
  String get disabledAndDenied;

  /// No description provided for @toTheRouteNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation to the stopped route'**
  String get toTheRouteNavigation;

  /// No description provided for @completedCourseNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation of the completed course'**
  String get completedCourseNavigation;

  /// No description provided for @startingPoint.
  ///
  /// In en, this message translates to:
  /// **'Starting point reached!'**
  String get startingPoint;

  /// No description provided for @startingPointNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation to the starting point...'**
  String get startingPointNavigation;

  /// No description provided for @arrivedToStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'You have arrived at the starting point of the course!'**
  String get arrivedToStartingPoint;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @startCourse.
  ///
  /// In en, this message translates to:
  /// **'Start the course'**
  String get startCourse;

  /// No description provided for @courseStarted.
  ///
  /// In en, this message translates to:
  /// **'Navigation of the course started...'**
  String get courseStarted;

  /// No description provided for @userAreStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'You are at the starting point of the course.'**
  String get userAreStartingPoint;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @routeCalculation.
  ///
  /// In en, this message translates to:
  /// **'Calculation of the route to the course...'**
  String get routeCalculation;

  /// No description provided for @unableCalculateRoute.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate the route to the course'**
  String get unableCalculateRoute;

  /// No description provided for @unableStartNavigation.
  ///
  /// In en, this message translates to:
  /// **'Unable to start navigation: {error}'**
  String unableStartNavigation(Object error);

  /// No description provided for @navigationServiceError.
  ///
  /// In en, this message translates to:
  /// **'The navigation service returned false'**
  String get navigationServiceError;

  /// No description provided for @calculationError.
  ///
  /// In en, this message translates to:
  /// **'Error calculation route'**
  String get calculationError;

  /// No description provided for @calculationRouteError.
  ///
  /// In en, this message translates to:
  /// **'Error calculation route: {error}'**
  String calculationRouteError(String error);

  /// No description provided for @navigationInitializedError.
  ///
  /// In en, this message translates to:
  /// **'Navigation error (service not initialized)'**
  String get navigationInitializedError;

  /// No description provided for @navigationError.
  ///
  /// In en, this message translates to:
  /// **'Error of the navigation service'**
  String get navigationError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @navigationToCourse.
  ///
  /// In en, this message translates to:
  /// **'Navigation to the course'**
  String get navigationToCourse;

  /// No description provided for @userToStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'You are {distance} from the starting point.'**
  String userToStartingPoint(String distance);

  /// No description provided for @askUserChooseRoute.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get askUserChooseRoute;

  /// No description provided for @voiceInstructions.
  ///
  /// In en, this message translates to:
  /// **'Navigation with voice instructions'**
  String get voiceInstructions;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @directPath.
  ///
  /// In en, this message translates to:
  /// **'Direct path'**
  String get directPath;

  /// No description provided for @guideMe.
  ///
  /// In en, this message translates to:
  /// **'Guide me'**
  String get guideMe;

  /// No description provided for @readyToStart.
  ///
  /// In en, this message translates to:
  /// **'Ready to start the navigation of the course'**
  String get readyToStart;

  /// No description provided for @notAvailablePosition.
  ///
  /// In en, this message translates to:
  /// **'User position or route not available'**
  String get notAvailablePosition;

  /// No description provided for @urbanization.
  ///
  /// In en, this message translates to:
  /// **'Level of urbanization'**
  String get urbanization;

  /// No description provided for @terrain.
  ///
  /// In en, this message translates to:
  /// **'Type of terrain'**
  String get terrain;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Type of activity'**
  String get activity;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevation;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get advancedOptions;

  /// No description provided for @loopCourse.
  ///
  /// In en, this message translates to:
  /// **'Loop course'**
  String get loopCourse;

  /// No description provided for @returnStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'Return to the starting point'**
  String get returnStartingPoint;

  /// No description provided for @avoidTraffic.
  ///
  /// In en, this message translates to:
  /// **'Avoid traffic'**
  String get avoidTraffic;

  /// No description provided for @quietStreets.
  ///
  /// In en, this message translates to:
  /// **'Prioritize quiet streets'**
  String get quietStreets;

  /// No description provided for @scenicRoute.
  ///
  /// In en, this message translates to:
  /// **'Scenic route'**
  String get scenicRoute;

  /// No description provided for @prioritizeLandscapes.
  ///
  /// In en, this message translates to:
  /// **'Prioritize beautiful landscapes'**
  String get prioritizeLandscapes;

  /// No description provided for @walking.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walking;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get running;

  /// No description provided for @cycling.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get cycling;

  /// No description provided for @nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// No description provided for @mixedUrbanization.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedUrbanization;

  /// No description provided for @urban.
  ///
  /// In en, this message translates to:
  /// **'Urban'**
  String get urban;

  /// No description provided for @flat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get flat;

  /// No description provided for @mixedTerrain.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedTerrain;

  /// No description provided for @hilly.
  ///
  /// In en, this message translates to:
  /// **'Hilly'**
  String get hilly;

  /// No description provided for @flatDesc.
  ///
  /// In en, this message translates to:
  /// **'Flat land with little elevation gain'**
  String get flatDesc;

  /// No description provided for @mixedTerrainDesc.
  ///
  /// In en, this message translates to:
  /// **'Varied terrain with moderate elevation gain'**
  String get mixedTerrainDesc;

  /// No description provided for @hillyDesc.
  ///
  /// In en, this message translates to:
  /// **'Land with a steep slope'**
  String get hillyDesc;

  /// No description provided for @natureDesc.
  ///
  /// In en, this message translates to:
  /// **'Mainly in nature'**
  String get natureDesc;

  /// No description provided for @mixedUrbanizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Mix city and nature'**
  String get mixedUrbanizationDesc;

  /// No description provided for @urbanDesc.
  ///
  /// In en, this message translates to:
  /// **'Mainly in the city'**
  String get urbanDesc;

  /// No description provided for @arriveAtDestination.
  ///
  /// In en, this message translates to:
  /// **'You arrive at your destination'**
  String get arriveAtDestination;

  /// No description provided for @continueOn.
  ///
  /// In en, this message translates to:
  /// **'Continue straight on {distance}m'**
  String continueOn(int distance);

  /// No description provided for @followPath.
  ///
  /// In en, this message translates to:
  /// **'Follow the path for {distance}km'**
  String followPath(String distance);

  /// App-bar title shown when the user tries to open a protected page while unauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Restricted access'**
  String get restrictedAccessTitle;

  /// Headline informing the user that they must authenticate first.
  ///
  /// In en, this message translates to:
  /// **'You are not logged in'**
  String get notLoggedIn;

  /// Explanation shown under the headline telling the user why authentication is required.
  ///
  /// In en, this message translates to:
  /// **'To access this page, please log in or create an account.'**
  String get loginOrCreateAccountHint;

  /// Label of the button that opens the login form.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// Label of the button that opens the sign-up form.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccount;

  /// Link prompting the user to contact support.
  ///
  /// In en, this message translates to:
  /// **'Need help? Contact us.'**
  String get needHelpContactUs;

  /// Subtitle explaining the sign-up steps
  ///
  /// In en, this message translates to:
  /// **'To create an account provide details, verify email and set a password.'**
  String get createAccountSubtitle;

  /// Placeholder of the e-mail text field
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailHint;

  /// Placeholder of the password text field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// Placeholder of the confirm-password text field
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordHint;

  /// Validation error shown when the two password fields differ
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatchError;

  /// Text preceding the Log in link
  ///
  /// In en, this message translates to:
  /// **'Have an account?'**
  String get haveAccount;

  /// Footer link to legal documents
  ///
  /// In en, this message translates to:
  /// **'Terms of Service | Privacy Policy'**
  String get termsAndPrivacy;

  /// Label on the primary sign-up button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueForms;

  /// Label on the Apple social-login button
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// Label on the Google social-login button
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  ///
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// Main greeting title on the log-in screen
  ///
  /// In en, this message translates to:
  /// **'Hi there!'**
  String get loginGreetingTitle;

  /// Subtitle asking the user to fill in the form
  ///
  /// In en, this message translates to:
  /// **'Please enter required details.'**
  String get loginGreetingSubtitle;

  /// Link or label that will lead to password-reset flow
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Text preceding the Sign-up link
  ///
  /// In en, this message translates to:
  /// **'Create an account?'**
  String get createAccountQuestion;

  /// Link that navigates to the sign-up screen
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// Temporary snackbar message shown when Apple login is not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Apple login – To be implemented'**
  String get appleLoginTodo;

  /// Temporary snackbar message shown when Google login is not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Google login – To be implemented'**
  String get googleLoginTodo;

  /// Title displayed in the app-bar of the onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Set up your account'**
  String get setupAccountTitle;

  /// Introductory sentence inviting the user to fill in all fields
  ///
  /// In en, this message translates to:
  /// **'Please complete all the information presented below to create your account.'**
  String get onboardingInstruction;

  /// Placeholder text for the full-name field
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get fullNameHint;

  /// Placeholder text for the username field
  ///
  /// In en, this message translates to:
  /// **'@johndoe'**
  String get usernameHint;

  /// Label of the button that finishes profile creation
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// Message shown in the loading overlay while the profile is being created
  ///
  /// In en, this message translates to:
  /// **'Creating your profile...'**
  String get creatingProfile;

  /// Validation error when the full-name field is empty
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameRequired;

  /// Validation error when the full-name is too short
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get fullNameMinLength;

  /// Validation error when the username field is empty
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// Validation error when the username is too short
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get usernameMinLength;

  /// Validation error when the username contains forbidden characters
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers and _ are allowed'**
  String get usernameInvalidChars;

  /// Snackbar message when the image picker fails
  ///
  /// In en, this message translates to:
  /// **'Error selecting image: {error}'**
  String imagePickError(Object error);

  /// Warning shown when the profile is saved but the avatar upload failed
  ///
  /// In en, this message translates to:
  /// **'Profile created but avatar could not be uploaded. You can add it later.'**
  String get avatarUploadWarning;

  /// Validation error shown when the e-mail format is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get emailInvalid;

  /// Validation error when the password is shorter than 6 characters
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @currentGeneration.
  ///
  /// In en, this message translates to:
  /// **'Current generation...'**
  String get currentGeneration;

  /// No description provided for @navigationPaused.
  ///
  /// In en, this message translates to:
  /// **'Navigation paused'**
  String get navigationPaused;

  /// No description provided for @navigationResumed.
  ///
  /// In en, this message translates to:
  /// **'Navigation resumed'**
  String get navigationResumed;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @elevationGain.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get elevationGain;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Est. Time'**
  String get estimatedTime;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
