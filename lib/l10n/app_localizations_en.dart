// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get elevation => 'Elevation';

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
  String get needHelpContactUs => 'Need help? Contact us.';

  @override
  String get createAccountSubtitle => 'To create an account provide details, verify email and set a password.';

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
  String get termsAndPrivacy => 'Terms of Service | Privacy Policy';

  @override
  String get continueForms => 'Continue';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get orDivider => 'OR';

  @override
  String get loginGreetingTitle => 'Hi there!';

  @override
  String get loginGreetingSubtitle => 'Please enter required details.';

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
}
