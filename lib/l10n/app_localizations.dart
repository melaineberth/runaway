import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

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
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it')
  ];

  /// Label for language selection setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Title for language selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Language selected
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get currentLanguage;

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

  /// Texte affiché pour indiquer la position GPS actuelle de l'utilisateur.
  ///
  /// In en, this message translates to:
  /// **'Current position'**
  String get currentPosition;

  /// Message d’erreur invitant l’utilisateur à relancer la recherche avec un rayon plus petit.
  ///
  /// In en, this message translates to:
  /// **'Try again with a smaller ray'**
  String get retrySmallRay;

  /// Erreur indiquant que le serveur n’a renvoyé aucune coordonnée.
  ///
  /// In en, this message translates to:
  /// **'No coordinate received from the server'**
  String get noCoordinateServer;

  /// Message d’erreur générique lorsqu’une génération de données échoue.
  ///
  /// In en, this message translates to:
  /// **'Error during the generation'**
  String get generationError;

  /// Message d’erreur lorsque les services de localisation sont désactivés sur l’appareil.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get disabledLocation;

  /// Message d’erreur lorsque l’utilisateur refuse ponctuellement l’autorisation de localisation.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied.'**
  String get deniedPermission;

  /// Message d’erreur lorsque l’utilisateur a refusé définitivement l’autorisation de localisation.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied, we cannot request permission.'**
  String get disabledAndDenied;

  /// Titre ou annonce de navigation visant à rejoindre un itinéraire interrompu.
  ///
  /// In en, this message translates to:
  /// **'Navigation to the stopped route'**
  String get toTheRouteNavigation;

  /// Titre ou annonce de navigation d’un parcours déjà terminé.
  ///
  /// In en, this message translates to:
  /// **'Navigation of the completed course'**
  String get completedCourseNavigation;

  /// Notification indiquant que le point de départ a été atteint.
  ///
  /// In en, this message translates to:
  /// **'Starting point reached!'**
  String get startingPoint;

  /// Message affiché pendant le guidage vers le point de départ.
  ///
  /// In en, this message translates to:
  /// **'Navigation to the starting point...'**
  String get startingPointNavigation;

  /// Message annonçant l’arrivée au point de départ du parcours.
  ///
  /// In en, this message translates to:
  /// **'You have arrived at the starting point of the course!'**
  String get arrivedToStartingPoint;

  /// Bouton ou action permettant de reporter une décision ou un rappel.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// Bouton ou commande pour débuter la navigation d’un parcours.
  ///
  /// In en, this message translates to:
  /// **'Start the course'**
  String get startCourse;

  /// Message indiquant que la navigation du parcours a commencé.
  ///
  /// In en, this message translates to:
  /// **'Navigation of the course started...'**
  String get courseStarted;

  /// Message informant l’utilisateur qu’il se trouve déjà sur le point de départ.
  ///
  /// In en, this message translates to:
  /// **'You are at the starting point of the course.'**
  String get userAreStartingPoint;

  /// Libellé générique pour une erreur dans une boîte de dialogue ou une bannière.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Message affiché pendant le calcul de l’itinéraire vers le parcours.
  ///
  /// In en, this message translates to:
  /// **'Calculation of the route to the course...'**
  String get routeCalculation;

  /// Message d’erreur lorsque le calcul d’itinéraire vers le parcours échoue.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate the route to the course'**
  String get unableCalculateRoute;

  /// No description provided for @unableStartNavigation.
  ///
  /// In en, this message translates to:
  /// **'Unable to start navigation: {error}'**
  String unableStartNavigation(Object error);

  /// Erreur renvoyée lorsque le service de navigation répond « false » (échec de l’appel).
  ///
  /// In en, this message translates to:
  /// **'The navigation service returned false'**
  String get navigationServiceError;

  /// Message d’erreur affiché quand le calcul d’itinéraire échoue.
  ///
  /// In en, this message translates to:
  /// **'Error calculation route'**
  String get calculationError;

  /// No description provided for @calculationRouteError.
  ///
  /// In en, this message translates to:
  /// **'Error calculation route: {error}'**
  String calculationRouteError(String error);

  /// Erreur indiquant que le service de navigation n’est pas initialisé lorsque l’on tente de l’utiliser.
  ///
  /// In en, this message translates to:
  /// **'Navigation error (service not initialized)'**
  String get navigationInitializedError;

  /// Message générique pour toute erreur provenant du service de navigation.
  ///
  /// In en, this message translates to:
  /// **'Error of the navigation service'**
  String get navigationError;

  /// Texte d’un bouton ou lien permettant de relancer l’opération après un échec.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Titre ou en-tête indiquant la navigation vers un parcours spécifique.
  ///
  /// In en, this message translates to:
  /// **'Navigation to the course'**
  String get navigationToCourse;

  /// No description provided for @userToStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'You are {distance} from the starting point.'**
  String userToStartingPoint(String distance);

  /// Question affichée dans une boîte de dialogue pour que l’utilisateur choisisse l’action à réaliser (ex. navigation ou création d’itinéraire).
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get askUserChooseRoute;

  /// Option permettant d’activer la navigation guidée par instructions vocales.
  ///
  /// In en, this message translates to:
  /// **'Navigation with voice instructions'**
  String get voiceInstructions;

  /// Libellé d’un bouton d’annulation ou pour fermer une boîte de dialogue.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Option proposant l’itinéraire le plus direct possible vers la destination.
  ///
  /// In en, this message translates to:
  /// **'Direct path'**
  String get directPath;

  /// Bouton demandant au système de commencer le guidage pas-à-pas jusqu’à la destination.
  ///
  /// In en, this message translates to:
  /// **'Guide me'**
  String get guideMe;

  /// Message indiquant que tout est prêt pour démarrer la navigation du parcours.
  ///
  /// In en, this message translates to:
  /// **'Ready to start the navigation of the course'**
  String get readyToStart;

  /// Avertissement affiché quand la position de l’utilisateur ou l’itinéraire est indisponible.
  ///
  /// In en, this message translates to:
  /// **'User position or route not available'**
  String get notAvailablePosition;

  /// Étiquette d’un champ ou filtre précisant le degré d’urbanisation souhaité pour le parcours.
  ///
  /// In en, this message translates to:
  /// **'Level of urbanization'**
  String get urbanization;

  /// Étiquette d’un champ ou filtre déterminant le type de terrain du parcours.
  ///
  /// In en, this message translates to:
  /// **'Type of terrain'**
  String get terrain;

  /// Étiquette d’un champ ou filtre pour sélectionner l’activité (marche, course, vélo…).
  ///
  /// In en, this message translates to:
  /// **'Type of activity'**
  String get activity;

  /// Champ indiquant la distance totale du parcours.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// Champ indiquant le dénivelé positif total du parcours.
  ///
  /// In en, this message translates to:
  /// **'Elevation gain'**
  String get elevation;

  /// Bouton pour lancer la génération d’un itinéraire sur mesure.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// Lien ou bouton ouvrant des paramètres avancés pour affiner la génération de parcours.
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get advancedOptions;

  /// Option permettant de générer un parcours en boucle (départ = arrivée).
  ///
  /// In en, this message translates to:
  /// **'Loop course'**
  String get loopCourse;

  /// Option pour demander un guidage retour vers le point de départ.
  ///
  /// In en, this message translates to:
  /// **'Return to the starting point'**
  String get returnStartingPoint;

  /// Option de génération d’itinéraire visant à éviter les zones à forte circulation.
  ///
  /// In en, this message translates to:
  /// **'Avoid traffic'**
  String get avoidTraffic;

  /// Option pour privilégier les rues calmes dans le calcul du parcours.
  ///
  /// In en, this message translates to:
  /// **'Prioritize quiet streets'**
  String get quietStreets;

  /// Option proposant un itinéraire pittoresque avec de beaux points de vue.
  ///
  /// In en, this message translates to:
  /// **'Scenic route'**
  String get scenicRoute;

  /// Option privilégiant les paysages attrayants lors de la génération de l’itinéraire.
  ///
  /// In en, this message translates to:
  /// **'Prioritize beautiful landscapes'**
  String get prioritizeLandscapes;

  /// Valeur d’activité représentant la marche à pied.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walking;

  /// Valeur d’activité représentant la course à pied.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get running;

  /// Valeur d’activité représentant le cyclisme.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get cycling;

  /// Niveau d’urbanisation : parcours principalement en milieu naturel.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// Niveau d’urbanisation : parcours mêlant ville et nature.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedUrbanization;

  /// Niveau d’urbanisation : parcours principalement urbain.
  ///
  /// In en, this message translates to:
  /// **'Urban'**
  String get urban;

  /// Type de terrain : plat (peu ou pas de dénivelé).
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get flat;

  /// Type de terrain : varié (combinaison de plat et de pentes modérées).
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedTerrain;

  /// Type de terrain : vallonné / pentes prononcées.
  ///
  /// In en, this message translates to:
  /// **'Hilly'**
  String get hilly;

  /// Description courte du terrain plat, utilisée dans des info-bulles ou listes.
  ///
  /// In en, this message translates to:
  /// **'Flat land with little elevation gain'**
  String get flatDesc;

  /// Description courte du terrain mixte, utilisée dans des info-bulles ou listes.
  ///
  /// In en, this message translates to:
  /// **'Varied terrain with moderate elevation gain'**
  String get mixedTerrainDesc;

  /// Description courte du terrain vallonné, utilisée dans des info-bulles ou listes.
  ///
  /// In en, this message translates to:
  /// **'Land with a steep slope'**
  String get hillyDesc;

  /// Description courte d’un parcours majoritairement en nature.
  ///
  /// In en, this message translates to:
  /// **'Mainly in nature'**
  String get natureDesc;

  /// Description courte d’un parcours mixte (ville + nature).
  ///
  /// In en, this message translates to:
  /// **'Mix city and nature'**
  String get mixedUrbanizationDesc;

  /// Description courte d’un parcours majoritairement urbain.
  ///
  /// In en, this message translates to:
  /// **'Mainly in the city'**
  String get urbanDesc;

  /// Annonce vocale ou notification indiquant l’arrivée à destination.
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
  /// **'Need help? '**
  String get needHelp;

  /// Sous-titre expliquant les étapes d'inscription
  ///
  /// In en, this message translates to:
  /// **'Ready for adventure?'**
  String get createAccountTitle;

  /// Subtitle explaining the sign-up steps
  ///
  /// In en, this message translates to:
  /// **'Create your account to discover unique routes and start exploring new sporting horizons'**
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
  /// **'Terms & Privacy'**
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
  /// **'Great to see you back!'**
  String get loginGreetingTitle;

  /// Subtitle asking the user to fill in the form
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account to access all your data and pick up where you left off'**
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

  /// Texte affiché pendant la génération en cours (parcours, statistiques, etc.).
  ///
  /// In en, this message translates to:
  /// **'Current generation...'**
  String get currentGeneration;

  /// Message indiquant que la navigation a été mise en pause.
  ///
  /// In en, this message translates to:
  /// **'Navigation paused'**
  String get navigationPaused;

  /// Message indiquant que la navigation a repris après la pause.
  ///
  /// In en, this message translates to:
  /// **'Navigation resumed'**
  String get navigationResumed;

  /// Étiquette pour la durée écoulée ou l’heure courante, selon le contexte.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Étiquette pour le rythme (ex. min/km ou min/mi) dans les statistiques d’activité.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// Étiquette pour la vitesse (ex. km/h ou mph) dans les statistiques d’activité.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// Étiquette pour le dénivelé positif total (gain d’altitude) du parcours.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get elevationGain;

  /// Étiquette indiquant la distance ou le temps restant avant l’arrivée ou la fin du parcours.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// Étiquette pour la progression réalisée (distance, temps ou pourcentage accompli).
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Étiquette pour le temps estimé avant d’atteindre la destination ou de terminer l’activité.
  ///
  /// In en, this message translates to:
  /// **'Est. Time'**
  String get estimatedTime;

  /// Top-snack-bar message shown while the new avatar is being uploaded and saved.
  ///
  /// In en, this message translates to:
  /// **'Updating the photo…'**
  String get updatingPhoto;

  /// Top-snack-bar message shown when the image picker throws an exception.
  ///
  /// In en, this message translates to:
  /// **'Error during selection: {error}'**
  String selectionError(String error);

  /// Title of the account screen (AppBar).
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Fallback name displayed when the profile has no full name.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUserName;

  /// Section heading for user-preference settings.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Label for the notifications setting row.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Label for the theme-selection setting row.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Value text indicating that a setting (e.g. notifications) is ON.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// Value text for the light-theme choice.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// Prompt inviting the user to choose their preferred theme.
  ///
  /// In en, this message translates to:
  /// **'Select your preference'**
  String get selectPreferenceTheme;

  /// Value text for the auto-theme choice (system theme).
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoTheme;

  /// Value text for the dark-theme choice.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// Section heading grouping account-related actions such as logout and delete profile.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// Action that logs the user out of the application.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Action that permanently deletes the user’s profile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// Button that should navigate to the profile-editing screen.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Temporary snack-bar informing that profile editing is not yet implemented.
  ///
  /// In en, this message translates to:
  /// **'Profile editing – To implement'**
  String get editProfileTodo;

  /// Title of the confirmation dialog displayed before logging out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutTitle;

  /// Body text of the log-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'You’ll be signed out of Trailix, but all your saved data and preferences will remain secure'**
  String get logoutMessage;

  /// Positive-action button in the log-out dialog.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutConfirm;

  /// Title of the confirmation dialog displayed before deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// Primary warning text in the delete-account dialog.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your Trailix account as well as all saved routes and preferences, this action cannot be undone'**
  String get deleteAccountMessage;

  /// Additional highlighted warning shown inside the delete-account dialog.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get deleteAccountWarning;

  /// Positive-action button in the delete-account dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Temporary snack-bar informing that account deletion is not yet implemented.
  ///
  /// In en, this message translates to:
  /// **'Account deletion – To implement'**
  String get deleteAccountTodo;

  /// Button shown under the enlarged avatar that lets the user choose a new profile picture.
  ///
  /// In en, this message translates to:
  /// **'Edit the photo'**
  String get editPhoto;

  /// Label for the setting that shows the language currently offered to the user.
  ///
  /// In en, this message translates to:
  /// **'Available language'**
  String get availableLanguage;

  /// Prompt inviting the user to choose their preferred language.
  ///
  /// In en, this message translates to:
  /// **'Select your preference'**
  String get selectPreferenceLanguage;

  /// Section header or field label that refers to the user's activity type.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// Button or menu item used to export the user's data (e.g., workouts, goals).
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// Button or menu item that resets all user-defined goals.
  ///
  /// In en, this message translates to:
  /// **'Reset goals'**
  String get resetGoals;

  /// Status message displayed while statistics are being calculated.
  ///
  /// In en, this message translates to:
  /// **'Calculation of statistics...'**
  String get statisticsCalculation;

  /// Generic loading indicator shown during any asynchronous operation.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Action label prompting the user to start creating a new goal.
  ///
  /// In en, this message translates to:
  /// **'Create a goal'**
  String get createGoal;

  /// Label indicating that a goal is user-defined rather than predefined.
  ///
  /// In en, this message translates to:
  /// **'Custom goal'**
  String get customGoal;

  /// Button or link to open the workflow for creating a user-defined goal.
  ///
  /// In en, this message translates to:
  /// **'Create a custom goal'**
  String get createCustomGoal;

  /// Title for the list of preset goal templates available to the user.
  ///
  /// In en, this message translates to:
  /// **'Goals models'**
  String get goalsModels;

  /// Instruction text inviting the user to pick one of the preset goal templates.
  ///
  /// In en, this message translates to:
  /// **'Choose from pre-defined goals'**
  String get predefinedGoals;

  /// Toast or confirmation message shown after a goal is successfully updated.
  ///
  /// In en, this message translates to:
  /// **'Updated goal'**
  String get updatedGoal;

  /// Toast or confirmation message shown after a goal is successfully created.
  ///
  /// In en, this message translates to:
  /// **'Goal created'**
  String get createdGoal;

  /// Dialog title asking the user to confirm deletion of a goal.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get deleteGoalTitle;

  /// Dialog body text warning the user that deleting the goal is irreversible.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this goal?'**
  String get deleteGoalMessage;

  /// Toast or confirmation message displayed after a goal has been deleted.
  ///
  /// In en, this message translates to:
  /// **'Goal removed'**
  String get removedGoal;

  /// Dialog title asking the user to confirm resetting all goals.
  ///
  /// In en, this message translates to:
  /// **'Reset the goals'**
  String get goalsResetTitle;

  /// Dialog body warning that the reset will delete every goal the user has set.
  ///
  /// In en, this message translates to:
  /// **'This action will remove all your goals. Are you sure?'**
  String get goalsResetMessage;

  /// Generic button label used to restore default values in a form or setting.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Label for a filter button that limits the list of items by activity type.
  ///
  /// In en, this message translates to:
  /// **'By activity'**
  String get activityFilter;

  /// Filter option that removes any active filters and shows every item.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// Summary text showing the total number of routes available. The number is inserted dynamically.
  ///
  /// In en, this message translates to:
  /// **'{totalRoutes} routes'**
  String totalRoutes(int totalRoutes);

  /// Message displayed when the current filter returns no results.
  ///
  /// In en, this message translates to:
  /// **'No data for this filter'**
  String get emptyDataFilter;

  /// Title or tooltip for an option that lets the user filter data by activity type.
  ///
  /// In en, this message translates to:
  /// **'Filter by activity'**
  String get byActivityFilter;

  /// Prompt asking the user to select an activity type from a list.
  ///
  /// In en, this message translates to:
  /// **'Choose the type of activity'**
  String get typeOfActivity;

  /// Dropdown option representing every possible activity type.
  ///
  /// In en, this message translates to:
  /// **'All activities'**
  String get allActivities;

  /// Button label that opens a form to edit an existing goal.
  ///
  /// In en, this message translates to:
  /// **'Modify goal'**
  String get modifyGoal;

  /// Button label that opens a form to create a new goal.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get newGoal;

  /// Generic action label used to edit the current item.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get modify;

  /// Generic action label used to create a new item.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Field label for entering the title of a goal.
  ///
  /// In en, this message translates to:
  /// **'Goal title'**
  String get goalTitle;

  /// Validation error shown when the goal title field is empty.
  ///
  /// In en, this message translates to:
  /// **'You should enter a title'**
  String get titleValidator;

  /// Label for an optional description field in a form.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get optionalDescription;

  /// Label for selecting the category of goal (distance, speed, etc.).
  ///
  /// In en, this message translates to:
  /// **'Goal type'**
  String get goalType;

  /// Label for an optional field where the user can link a goal to a specific activity.
  ///
  /// In en, this message translates to:
  /// **'Activity (optional)'**
  String get optionalActivity;

  /// Label for the numeric target value of a goal.
  ///
  /// In en, this message translates to:
  /// **'Target value'**
  String get targetValue;

  /// Validation error shown when the target value field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a target value'**
  String get targetValueValidator;

  /// Validation error shown when the entered value is zero or negative.
  ///
  /// In en, this message translates to:
  /// **'Please enter a positive value'**
  String get positiveValueValidator;

  /// Label for an optional date picker that sets a deadline for the goal.
  ///
  /// In en, this message translates to:
  /// **'Deadline (optional)'**
  String get optionalDeadline;

  /// Prompt on the date picker button inviting the user to choose a date.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get selectDate;

  /// Unit label for distance displayed in kilometers.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get distanceType;

  /// Unit label representing a count of individual routes.
  ///
  /// In en, this message translates to:
  /// **'routes'**
  String get routesType;

  /// Unit label for speed displayed in kilometers per hour.
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get speedType;

  /// Unit label for elevation gain displayed in meters.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get elevationType;

  /// Name of a goal category that tracks total distance per month.
  ///
  /// In en, this message translates to:
  /// **'Monthly distance'**
  String get goalTypeDistance;

  /// Name of a goal category that tracks how many routes are completed.
  ///
  /// In en, this message translates to:
  /// **'Number of routes'**
  String get goalTypeRoutes;

  /// Name of a goal category that tracks the average speed over a period.
  ///
  /// In en, this message translates to:
  /// **'Aver. speed'**
  String get goalTypeSpeed;

  /// Name of a goal category that tracks cumulative elevation gain.
  ///
  /// In en, this message translates to:
  /// **'Total elevation gain'**
  String get goalTypeElevation;

  /// Default title for a sample goal focused on monthly running distance.
  ///
  /// In en, this message translates to:
  /// **'Monthly race'**
  String get monthlyRaceTitle;

  /// Short description of the monthly running distance goal.
  ///
  /// In en, this message translates to:
  /// **'50km per month of running'**
  String get monthlyRaceMessage;

  /// Goal summary stating the user should run 50 km each month.
  ///
  /// In en, this message translates to:
  /// **'Run 50km per month'**
  String get monthlyRaceGoal;

  /// Default title for a sample goal focused on weekly cycling distance.
  ///
  /// In en, this message translates to:
  /// **'Weekly bike'**
  String get weeklyBikeTitle;

  /// Short description of the weekly cycling distance goal.
  ///
  /// In en, this message translates to:
  /// **'100km per week by bike'**
  String get weeklyBikeMessage;

  /// Goal summary stating the user should cycle 100 km each week.
  ///
  /// In en, this message translates to:
  /// **'Ride a bike for 100km per week'**
  String get weeklyBikeGoal;

  /// Default title for a sample goal that counts the number of routes per month.
  ///
  /// In en, this message translates to:
  /// **'Regular courses'**
  String get regularTripsTitle;

  /// Short description of the monthly routes goal.
  ///
  /// In en, this message translates to:
  /// **'10 courses per month'**
  String get regularTripsMessage;

  /// Goal summary stating the user should complete 10 routes each month.
  ///
  /// In en, this message translates to:
  /// **'Complete 10 courses per month'**
  String get regularTripsGoal;

  /// Default title for a sample goal focused on monthly elevation gain.
  ///
  /// In en, this message translates to:
  /// **'Mountain Challenge'**
  String get mountainChallengeTitle;

  /// Short description of the monthly elevation gain goal.
  ///
  /// In en, this message translates to:
  /// **'1000m of elevation gain per month'**
  String get mountainChallengeMessage;

  /// Goal summary stating the user should achieve 1000 m of elevation gain each month.
  ///
  /// In en, this message translates to:
  /// **'Climb 1000m of elevation gain per month'**
  String get mountainChallengeGoal;

  /// Default title for a sample goal focused on maintaining average speed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get averageSpeedTitle;

  /// Short description of the average speed goal.
  ///
  /// In en, this message translates to:
  /// **'Maintain 12km/h of average'**
  String get averageSpeedMessage;

  /// Goal summary stating the user should keep an average speed of 12 km/h.
  ///
  /// In en, this message translates to:
  /// **'Maintain an average speed of 12km/h'**
  String get averageSpeedGoal;

  /// Section header listing all user-defined goals.
  ///
  /// In en, this message translates to:
  /// **'Personal goals'**
  String get personalGoals;

  /// Button label used to add a new item (goal, record, etc.).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Message shown when the user has not created any goals yet.
  ///
  /// In en, this message translates to:
  /// **'You have no defined goals'**
  String get emptyDefinedGoals;

  /// Instruction telling the user how to start adding a new goal.
  ///
  /// In en, this message translates to:
  /// **'Press + to create one'**
  String get pressToAdd;

  /// Section header listing the user's best performances.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get personalRecords;

  /// Message shown when no personal records exist yet.
  ///
  /// In en, this message translates to:
  /// **'Complete courses to establish your records'**
  String get empryPersonalRecords;

  /// Tab or section title showing a summary of statistics.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Label for the cumulative distance statistic.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get totalDistance;

  /// Label for the cumulative time statistic.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get totalTime;

  /// Dialog title shown when the user is about to delete a saved route.
  ///
  /// In en, this message translates to:
  /// **'Confirm the deletion'**
  String get confirmRouteDeletionTitle;

  /// Confirmation message asking whether the user truly wants to delete a specific route.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete the {routeName} route?'**
  String confirmRouteDeletionMessage(String routeName);

  /// Tab or section title that opens the list of previously completed routes.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get historic;

  /// Generic error label shown when data fails to load.
  ///
  /// In en, this message translates to:
  /// **'Loading error'**
  String get loadingError;

  /// Title displayed when the user has not yet saved any routes.
  ///
  /// In en, this message translates to:
  /// **'No route saved'**
  String get emptySavedRouteTitle;

  /// Message encouraging the user to create their first route when the saved-routes list is empty.
  ///
  /// In en, this message translates to:
  /// **'Generate your first route from the homepage to see it appear here'**
  String get emptySavedRouteMessage;

  /// Button text that triggers the route-generation process.
  ///
  /// In en, this message translates to:
  /// **'Generate a route'**
  String get generateRoute;

  /// Label or column header indicating a single route entry.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// Label for totals (distance, elevation, etc.) in summary views.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Status label shown when a route has not been synchronized to the server.
  ///
  /// In en, this message translates to:
  /// **'Unsync'**
  String get unsynchronized;

  /// Status label indicating that a route is already synchronized with the server.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get synchronized;

  /// Action item allowing the user to rename a saved route.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameRoute;

  /// Action item that uploads or synchronizes a route to the server.
  ///
  /// In en, this message translates to:
  /// **'Synchronize'**
  String get synchronizeRoute;

  /// Action item that deletes a saved route.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteRoute;

  /// Action item that starts guidance along the selected route.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followRoute;

  /// Fallback text shown when a route thumbnail or preview image cannot be displayed.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get imageUnavailable;

  /// Title for the UI section where users choose a map style.
  ///
  /// In en, this message translates to:
  /// **'Type of card'**
  String get mapStyleTitle;

  /// Subtitle prompting the user to pick their preferred map style.
  ///
  /// In en, this message translates to:
  /// **'Choose your style'**
  String get mapStyleSubtitle;

  /// Map-layer option that displays a classic street map with roads, place names and basic landmarks.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get mapStyleStreet;

  /// Map-layer option optimized for outdoor activities; highlights trails, terrain contours and natural features.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get mapStyleOutdoor;

  /// Map-layer option with a light color palette, suitable for bright environments or printing.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get mapStyleLight;

  /// Map-layer option with a dark color palette, ideal for night mode or low-light conditions.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get mapStyleDark;

  /// Map-layer option that shows high-resolution satellite imagery without additional labels.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapStyleSatellite;

  /// Map-layer option that overlays place labels and roads on top of satellite imagery.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get mapStyleHybrid;

  /// Label displayed next to the field where the user enters their full legal name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameTitle;

  /// Label for the unique username (handle) field shown in the profile form.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameTitle;

  /// Informational message shown when the username field is locked and cannot be altered.
  ///
  /// In en, this message translates to:
  /// **'The username cannot be modified'**
  String get nonEditableUsername;

  /// Success toast or alert shown after the user details are saved without errors.
  ///
  /// In en, this message translates to:
  /// **'Successfully updated profile'**
  String get profileUpdated;

  /// Generic error message displayed when saving profile changes fails.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile'**
  String get profileUpdateError;

  /// Link prompting the user to contact support.
  ///
  /// In en, this message translates to:
  /// **'Contact us.'**
  String get contactUs;

  /// Label for a button or link that lets the user modify an existing goal.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoal;

  /// Message showing the expiry date of an item; {date} will be replaced by a formatted date.
  ///
  /// In en, this message translates to:
  /// **'Valid until the {date}'**
  String deadlineValid(String date);

  /// Label for a button or link that lets the user download a file or data.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Label for a button that saves the current item, form, or changes.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Status text shown while the save operation is in progress.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// Status text indicating the item has previously been saved.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get alreadySaved;

  /// Tab or section title that opens the home view.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Label for a screen, menu item, or tab that lists helpful resources such as documentation, tutorials, or FAQs.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// Button or link that opens a channel (e-mail, chat, form) for the user to reach technical support.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// Call-to-action inviting the user to leave a rating or review in the app store.
  ///
  /// In en, this message translates to:
  /// **'Rate in store'**
  String get rateInStore;

  /// Button or link encouraging the user to follow the official @Trailix account on the X (formerly Twitter) social network.
  ///
  /// In en, this message translates to:
  /// **'Follow @Trailix'**
  String get followOnX;

  /// Subject line for the support email.
  ///
  /// In en, this message translates to:
  /// **'Issue with your app'**
  String get supportEmailSubject;

  /// Body content for the support email.
  ///
  /// In en, this message translates to:
  /// **'Hello Trailix Support,\n\nI\'m having trouble in the app.\nCould you please help me resolve this?\n\nThank you.'**
  String get supportEmailBody;

  /// Titre affiché quand l'utilisateur n'a pas assez de crédits
  ///
  /// In en, this message translates to:
  /// **'Insufficient credits'**
  String get insufficientCreditsTitle;

  /// Description expliquant le manque de crédits
  ///
  /// In en, this message translates to:
  /// **'You need {requiredCredits} credit(s) to {action}. You currently have {availableCredits} credit(s).'**
  String insufficientCreditsDescription(int requiredCredits, String action, int availableCredits);

  /// Bouton pour acheter des crédits
  ///
  /// In en, this message translates to:
  /// **'Buy credits'**
  String get buyCredits;

  /// Label pour afficher les crédits actuels
  ///
  /// In en, this message translates to:
  /// **'Current credits'**
  String get currentCredits;

  /// Label pour les crédits disponibles
  ///
  /// In en, this message translates to:
  /// **'Available credits'**
  String get availableCredits;

  /// Label pour le total de crédits utilisés
  ///
  /// In en, this message translates to:
  /// **'Total used'**
  String get totalUsed;

  /// Badge pour le plan le plus populaire
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// Bouton pour acheter le plan sélectionné
  ///
  /// In en, this message translates to:
  /// **'Buy this plan'**
  String get buySelectedPlan;

  /// Message quand aucun plan n'est sélectionné
  ///
  /// In en, this message translates to:
  /// **'Select a plan'**
  String get selectPlan;

  /// Titre pour la simulation d'achat
  ///
  /// In en, this message translates to:
  /// **'Purchase simulated'**
  String get purchaseSimulated;

  /// Description pour la simulation d'achat
  ///
  /// In en, this message translates to:
  /// **'In development mode, purchases are simulated. Do you want to simulate this purchase?'**
  String get purchaseSimulatedDescription;

  /// Bouton pour simuler un achat
  ///
  /// In en, this message translates to:
  /// **'Simulate purchase'**
  String get simulatePurchase;

  /// Titre de succès d'achat
  ///
  /// In en, this message translates to:
  /// **'Purchase successful!'**
  String get purchaseSuccess;

  /// Titre de l'écran d'historique
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get transactionHistory;

  /// Message quand il n'y a pas de transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// Libellé pour hier dans les dates
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Suffixe pour les jours passés
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysAgo;

  /// Bouton OK générique
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Message de succès d'utilisation de crédits
  ///
  /// In en, this message translates to:
  /// **'Credits used successfully'**
  String get creditUsageSuccess;

  /// Information sur l'utilisation de crédits pour la génération
  ///
  /// In en, this message translates to:
  /// **'1 credit will be used to generate this route'**
  String get routeGenerationWithCredits;

  /// Description de l'action qui consomme des crédits
  ///
  /// In en, this message translates to:
  /// **'Route generation (1 credit)'**
  String get creditsRequiredForGeneration;

  /// Lien pour gérer les crédits
  ///
  /// In en, this message translates to:
  /// **'Manage my credits'**
  String get manageCredits;

  /// Message de bienvenue avec crédits gratuits
  ///
  /// In en, this message translates to:
  /// **'🎉 Welcome! You have received 3 free credits to start'**
  String get freeCreditsWelcome;

  /// Affichage du nombre de crédits restants
  ///
  /// In en, this message translates to:
  /// **'{count} credit(s) left'**
  String creditsLeft(int count);

  /// Total elevation gain and loss over a route
  ///
  /// In en, this message translates to:
  /// **'Elevation range'**
  String get elevationRange;

  /// Lowest elevation reached in the route
  ///
  /// In en, this message translates to:
  /// **'Minimum elevation'**
  String get minElevation;

  /// Highest elevation reached in the route
  ///
  /// In en, this message translates to:
  /// **'Maximum elevation'**
  String get maxElevation;

  /// Level of difficulty of the route (easy, medium, hard)
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// Steepest incline on the route
  ///
  /// In en, this message translates to:
  /// **'Maximum incline'**
  String get maxIncline;

  /// Number of points of interest or checkpoints on the route
  ///
  /// In en, this message translates to:
  /// **'Waypoints'**
  String get waypointsCount;

  /// Points unit for the user (e.g., 45 pts earned)
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get points;

  /// User preference for the type of surface on the route
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get surfacePreference;

  /// Surface option for natural trails (dirt, gravel, forest paths)
  ///
  /// In en, this message translates to:
  /// **'Natural paths'**
  String get naturalPaths;

  /// Surface option for asphalt or paved roads
  ///
  /// In en, this message translates to:
  /// **'Paved roads'**
  String get pavedRoads;

  /// Surface option combining natural paths and paved roads
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixed;

  /// Preference to exclude highways from the route
  ///
  /// In en, this message translates to:
  /// **'Avoid highways'**
  String get avoidHighways;

  /// Preference to avoid large or busy roads
  ///
  /// In en, this message translates to:
  /// **'Avoid major roads'**
  String get avoidMajorRoads;

  /// Preference to go through or along parks
  ///
  /// In en, this message translates to:
  /// **'Prioritize parks'**
  String get prioritizeParks;

  /// Preference to include green spaces in the route
  ///
  /// In en, this message translates to:
  /// **'Prefer green spaces'**
  String get preferGreenSpaces;

  /// Total elevation descent over the course of the route
  ///
  /// In en, this message translates to:
  /// **'Elevation loss'**
  String get elevationLoss;

  /// Estimated duration of the route (in minutes or hours)
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Estimated number of calories burned on the route
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// How scenic or visually pleasant the route is
  ///
  /// In en, this message translates to:
  /// **'Scenic'**
  String get scenic;

  /// Maximum slope value on the route (uphill or downhill)
  ///
  /// In en, this message translates to:
  /// **'Max slope'**
  String get maxSlope;

  /// Key points or notable places along the route
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// Types of surfaces found or available on the route
  ///
  /// In en, this message translates to:
  /// **'Surfaces'**
  String get surfaces;

  /// Label for easy difficulty level for a route or activity.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easyDifficultyLevel;

  /// Label for moderate difficulty level for a route or activity.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderateDifficultyLevel;

  /// Label for hard difficulty level for a route or activity.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hardDifficultyLevel;

  /// Label for expert difficulty level for a route or activity.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get expertDifficultyLevel;

  /// Title for a surface type that uses asphalt roads or sidewalks.
  ///
  /// In en, this message translates to:
  /// **'Asphalt'**
  String get asphaltSurfaceTitle;

  /// Description for asphalt surface, prioritizing paved roads and sidewalks.
  ///
  /// In en, this message translates to:
  /// **'Prioritizes paved roads and sidewalks'**
  String get asphaltSurfaceDesc;

  /// Title for a surface type mixing roads and paths.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedSurfaceTitle;

  /// Description for mixed surface type, combining roads and paths.
  ///
  /// In en, this message translates to:
  /// **'Mix of roads and paths according to the route'**
  String get mixedSurfaceDesc;

  /// Title for a surface type using natural trails and paths.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get naturalSurfaceTitle;

  /// Description for natural surface, prioritizing natural trails and paths.
  ///
  /// In en, this message translates to:
  /// **'Prioritizes natural trails and paths'**
  String get naturalSurfaceDesc;

  /// Placeholder text for search field to find an address.
  ///
  /// In en, this message translates to:
  /// **'Search for an address...'**
  String get searchAdress;

  /// Label prompting the user to choose a name for a route.
  ///
  /// In en, this message translates to:
  /// **'Choose a name'**
  String get chooseName;

  /// Hint that the user can modify the chosen name later.
  ///
  /// In en, this message translates to:
  /// **'You can modify it later'**
  String get canModifyLater;

  /// Label for the route name input field.
  ///
  /// In en, this message translates to:
  /// **'Route name'**
  String get routeName;

  /// Message shown when the user has reached the limit of allowed generations.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get limitReachedGenerations;

  /// Message indicating all allowed generations have been exhausted.
  ///
  /// In en, this message translates to:
  /// **'Exhausted generations'**
  String get exhaustedGenerations;

  /// Label indicating how many generations the user can still perform.
  ///
  /// In en, this message translates to:
  /// **'Remaining limit'**
  String get remainingLimitGenerations;

  /// Label showing how many free generations remain, with correct pluralization for 'generation'.
  ///
  /// In en, this message translates to:
  /// **'{remainingGenerations} free generation{remainingGenerations, plural, =1 {} other {s}}'**
  String remainingGenerationsLabel(int remainingGenerations);

  /// Label for free generations quota.
  ///
  /// In en, this message translates to:
  /// **'Free generations'**
  String get freeGenerations;

  /// Message shown when free generations quota is exhausted.
  ///
  /// In en, this message translates to:
  /// **'Exhausted free generations'**
  String get exhaustedFreeGenerations;

  /// Message shown when all credits are used up.
  ///
  /// In en, this message translates to:
  /// **'Credits exhausted'**
  String get exhaustedCredits;

  /// Prompt telling the user to create an account for more generations.
  ///
  /// In en, this message translates to:
  /// **'Create a free account for more generations'**
  String get authForMoreGenerations;

  /// Label for button or link to create a free account.
  ///
  /// In en, this message translates to:
  /// **'Create a free account'**
  String get createFreeAccount;

  /// Title for exporting a route.
  ///
  /// In en, this message translates to:
  /// **'Export the route'**
  String get exportRouteTitle;

  /// Description text explaining how to choose the export format.
  ///
  /// In en, this message translates to:
  /// **'Choose the export format'**
  String get exportRouteDesc;

  /// Message shown when the route is being generated.
  ///
  /// In en, this message translates to:
  /// **'Generation of the route...'**
  String get generateInProgress;

  /// Message shown when there is no route to save.
  ///
  /// In en, this message translates to:
  /// **'No route to save'**
  String get emptyRouteForSave;

  /// Message shown when there is a connection error.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// Message shown when the map is not available.
  ///
  /// In en, this message translates to:
  /// **'Map not available'**
  String get notAvailableMap;

  /// Message shown when route settings are missing.
  ///
  /// In en, this message translates to:
  /// **'Missing route settings'**
  String get missingRouteSettings;

  /// Confirmation message that the route has been saved.
  ///
  /// In en, this message translates to:
  /// **'Saved route'**
  String get savedRoute;

  /// Title for a dialog or screen indicating login is required.
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get loginRequiredTitle;

  /// Description explaining why login is required.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to save your courses'**
  String get loginRequiredDesc;

  /// Title for a confirmation dialog asking if the user really wants to continue.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to continue?'**
  String get reallyContinueTitle;

  /// Description warning the user that continuing will delete the current route.
  ///
  /// In en, this message translates to:
  /// **'This action will delete the previously generated route, it will then be unrecoverable!'**
  String get reallyContinueDesc;

  /// Message indicating no position is available for generating a route.
  ///
  /// In en, this message translates to:
  /// **'No position available for the generation'**
  String get generationEmptyLocation;

  /// Message shown when generation cannot be launched due to an error.
  ///
  /// In en, this message translates to:
  /// **'Unable to launch the generation'**
  String get unableLaunchGeneration;

  /// Message shown when input parameters are invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid parameters'**
  String get invalidParameters;

  /// Status text displayed when the app is determining the user's location.
  ///
  /// In en, this message translates to:
  /// **'Location...'**
  String get locationInProgress;

  /// Prompt shown while searching for the user’s GPS position.
  ///
  /// In en, this message translates to:
  /// **'Search for your position'**
  String get searchingPosition;

  /// Error message displayed when there is a failure in location tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking error'**
  String get trackingError;

  /// Prompt for user to enter their authentication details
  ///
  /// In en, this message translates to:
  /// **'Enter your details'**
  String get enterAuthDetails;

  /// Prompt to enter a password
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get enterPassword;

  /// Button to continue authentication with email
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get continueWithEmail;

  /// Indicates a very weak password
  ///
  /// In en, this message translates to:
  /// **'Very weak'**
  String get passwordVeryWeak;

  /// Indicates a weak password
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordWeak;

  /// Indicates a fair password
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordFair;

  /// Indicates a good password
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordGood;

  /// Indicates a strong password
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrong;

  /// Confirmation that reset email was sent
  ///
  /// In en, this message translates to:
  /// **'Reset email sent to {email}'**
  String resetEmail(String email);

  /// Error message for missing password
  ///
  /// In en, this message translates to:
  /// **'Required password'**
  String get requiredPassword;

  /// Message stating the minimum number of characters
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters required'**
  String requiredCountCharacters(int count);

  /// Message that at least one uppercase letter is required
  ///
  /// In en, this message translates to:
  /// **'At least one capital letter required'**
  String get requiredCapitalLetter;

  /// Message that at least one lowercase letter is required
  ///
  /// In en, this message translates to:
  /// **'At least one minuscule required'**
  String get requiredMinusculeLetter;

  /// Message that at least one digit is required
  ///
  /// In en, this message translates to:
  /// **'At least one required digit'**
  String get requiredDigit;

  /// Message that at least one symbol is required
  ///
  /// In en, this message translates to:
  /// **'At least one required symbol'**
  String get requiredSymbol;

  /// Minimum number of characters required
  ///
  /// In en, this message translates to:
  /// **'Minimum {count} characters'**
  String minimumCountCharacters(int count);

  /// Requirement for one uppercase letter
  ///
  /// In en, this message translates to:
  /// **'One capital letter'**
  String get oneCapitalLetter;

  /// Requirement for one lowercase letter
  ///
  /// In en, this message translates to:
  /// **'One minuscule letter'**
  String get oneMinusculeLetter;

  /// Requirement for one digit
  ///
  /// In en, this message translates to:
  /// **'One digit'**
  String get oneDigit;

  /// Requirement for one symbol
  ///
  /// In en, this message translates to:
  /// **'One symbol'**
  String get oneSymbol;

  /// Success message for email confirmation sent
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent back successfully'**
  String get successEmailSentBack;

  /// Prompt to check email
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmail;

  /// Message confirming confirmation link sent
  ///
  /// In en, this message translates to:
  /// **'We have sent a confirmation link to {email}. Click on the link in the email to activate your account.'**
  String successSentConfirmationLink(String email);

  /// Action to resend the code
  ///
  /// In en, this message translates to:
  /// **'Resend the code'**
  String get resendCode;

  /// Message to resend code with delay
  ///
  /// In en, this message translates to:
  /// **'Resend in {count}s'**
  String resendCodeInDelay(int count);

  /// Navigate back to login
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get loginBack;

  /// Error message for missing email
  ///
  /// In en, this message translates to:
  /// **'Required email'**
  String get requiredEmail;

  /// Instruction to enter email for reset link
  ///
  /// In en, this message translates to:
  /// **'Enter your email address to receive a reset link'**
  String get receiveResetLink;

  /// Action to send
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Indicates default value
  ///
  /// In en, this message translates to:
  /// **'By default'**
  String get byDefault;

  /// Action to change user photo
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// Prompt to choose selection mode
  ///
  /// In en, this message translates to:
  /// **'Before continuing, please choose the desired selection mode'**
  String get desiredSelectionMode;

  /// Camera mode option
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraMode;

  /// Gallery mode option
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryMode;

  /// Success message when profile is updated
  ///
  /// In en, this message translates to:
  /// **'Successfully updated profile'**
  String get successUpdatedProfile;

  /// Error message when URL cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Could not launch {url}'**
  String couldNotLaunchUrl(String url);

  /// Error message when email app cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Could not launch email app'**
  String get couldNotLaunchEmailApp;

  /// Label for user balance
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get userBalance;

  /// Label for purchased credits
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get purchasedCredits;

  /// Label for used credits
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get usedCredits;

  /// Title for purchased credits section
  ///
  /// In en, this message translates to:
  /// **'Purchased credits'**
  String get purchaseCreditsTitle;

  /// Title for credit usage to generate route
  ///
  /// In en, this message translates to:
  /// **'Credit to generate a route'**
  String get usageCreditsTitle;

  /// Title for free welcome credits
  ///
  /// In en, this message translates to:
  /// **'Free welcome credits'**
  String get bonusCreditsTitle;

  /// Title for restored credits
  ///
  /// In en, this message translates to:
  /// **'Restored credits'**
  String get refundCreditsTitle;

  /// Message when plans are not available
  ///
  /// In en, this message translates to:
  /// **'Plans not available'**
  String get notAvailablePlans;

  /// Error when transaction ID is missing
  ///
  /// In en, this message translates to:
  /// **'Missing transaction ID'**
  String get missingTransactionID;

  /// Message when purchase is canceled
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled'**
  String get purchaseCanceled;

  /// Generic unknown error message
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// Error message for payment failure
  ///
  /// In en, this message translates to:
  /// **'Error during payment'**
  String get duringPaymentError;

  /// Error message for network exception
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Please try again.'**
  String get networkException;

  /// Error message when retrying unavailable plan
  ///
  /// In en, this message translates to:
  /// **'Selected plan not available. Please try again.'**
  String get retryNotAvailablePlans;

  /// Title for system issue detection
  ///
  /// In en, this message translates to:
  /// **'System issue detected'**
  String get systemIssueDetectedTitle;

  /// Subtitle for system issue detection
  ///
  /// In en, this message translates to:
  /// **'A system issue has been detected. This may happen if previous purchases did not complete correctly.'**
  String get systemIssueDetectedSubtitle;

  /// Instruction to restart app for system issue
  ///
  /// In en, this message translates to:
  /// **'Restart the application and try again'**
  String get systemIssueDetectedDesc;

  /// Action to close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Message when cleaning is done
  ///
  /// In en, this message translates to:
  /// **'Cleaning done. Try again now.'**
  String get cleaningDone;

  /// Error message when cleaning fails
  ///
  /// In en, this message translates to:
  /// **'Error while cleaning: {error}'**
  String cleaningError(String error);

  /// Label for cleaning process
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get cleaning;

  /// Title for credit plan modal
  ///
  /// In en, this message translates to:
  /// **'Stock up on credits to live new adventures!'**
  String get creditPlanModalTitle;

  /// Subtitle for credit plan modal
  ///
  /// In en, this message translates to:
  /// **'Choose your favorite package, then click here to start exploring!'**
  String get creditPlanModalSubtitle;

  /// Warning for credit plan modal
  ///
  /// In en, this message translates to:
  /// **'Payment debited upon confirmation of purchase. Credits are non-refundable and valid only in the application.'**
  String get creditPlanModalWarning;

  /// Action to refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Success message for route deletion
  ///
  /// In en, this message translates to:
  /// **'Route successfully deleted'**
  String get successRouteDeleted;

  /// Error message for route deletion failure
  ///
  /// In en, this message translates to:
  /// **'Error while deleting'**
  String get errorRouteDeleted;

  /// Error message for display route
  ///
  /// In en, this message translates to:
  /// **'Error during the display of the course'**
  String get displayRouteError;

  /// Error for empty route name
  ///
  /// In en, this message translates to:
  /// **'The name cannot be empty'**
  String get routeNameUpdateException;

  /// Error for minimum characters in route name
  ///
  /// In en, this message translates to:
  /// **'The name must contain at least 2 characters'**
  String get routeNameUpdateExceptionMinCharacters;

  /// Error for exceeding characters in route name
  ///
  /// In en, this message translates to:
  /// **'The name cannot exceed 50 characters'**
  String get routeNameUpdateExceptionCountCharacters;

  /// Error for forbidden characters in route name
  ///
  /// In en, this message translates to:
  /// **'The name contains forbidden characters'**
  String get routeNameUpdateExceptionForbiddenCharacters;

  /// Confirmation that route name was updated
  ///
  /// In en, this message translates to:
  /// **'Update done'**
  String get routeNameUpdateDone;

  /// Message for route export format
  ///
  /// In en, this message translates to:
  /// **'Route exported in {format}'**
  String formatRouteExport(String format);

  /// Error message for route export
  ///
  /// In en, this message translates to:
  /// **'Error during export: {error}'**
  String routeExportError(String error);

  /// Title for updating route name
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateRouteNameTitle;

  /// Subtitle for updating route name
  ///
  /// In en, this message translates to:
  /// **'Choose a new name'**
  String get updateRouteNameSubtitle;

  /// Hint text for updating route name
  ///
  /// In en, this message translates to:
  /// **'Digestive process after eating'**
  String get updateRouteNameHint;

  /// Error message displayed when the app fails to initialize properly.
  ///
  /// In en, this message translates to:
  /// **'Initialization error'**
  String get initializationError;

  /// Name of the GPX export format option.
  ///
  /// In en, this message translates to:
  /// **'Garmin / Komoot...'**
  String get gpxFormatName;

  /// Description of what GPX format is used for.
  ///
  /// In en, this message translates to:
  /// **'To export in GPX File'**
  String get gpxFormatDescription;

  /// Name of the KML export format option.
  ///
  /// In en, this message translates to:
  /// **'Google Maps / Earth...'**
  String get kmlFormatName;

  /// Description of what KML format is used for.
  ///
  /// In en, this message translates to:
  /// **'To export in KML File'**
  String get kmlFormatDescription;

  /// Text displayed when sharing a route export, indicating the source app.
  ///
  /// In en, this message translates to:
  /// **'Route exported from Trailix'**
  String get routeExportedFrom;

  /// Description text for exported route files.
  ///
  /// In en, this message translates to:
  /// **'{activityType} route of {distance}km generated by Trailix'**
  String routeDescription(String activityType, String distance);

  /// Label showing the distance of a route.
  ///
  /// In en, this message translates to:
  /// **'Route of {distance}km'**
  String routeDistanceLabel(String distance);

  /// Label for the end point marker of a route.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endPoint;

  /// Message shown when there is no route to export.
  ///
  /// In en, this message translates to:
  /// **'No route to export'**
  String get emptyRouteForExport;

  /// Error message displayed when a server error occurs and user should retry later.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverErrorRetry;

  /// Generic error message asking the user to retry.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get genericErrorRetry;

  /// Error message for invalid API requests.
  ///
  /// In en, this message translates to:
  /// **'Invalid request'**
  String get invalidRequest;

  /// Error message when the service is temporarily unavailable.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Try again in a few minutes.'**
  String get serviceUnavailable;

  /// Error message when a request times out.
  ///
  /// In en, this message translates to:
  /// **'Timeout exceeded. Check your connection.'**
  String get timeoutError;

  /// Error message for unexpected server errors.
  ///
  /// In en, this message translates to:
  /// **'Unexpected server error'**
  String get unexpectedServerError;

  /// Error message for server errors with status code.
  ///
  /// In en, this message translates to:
  /// **'Server error ({statusCode})'**
  String serverErrorCode(int statusCode);

  /// Error message when there is no internet connection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network.'**
  String get noInternetConnection;

  /// Error message for timeout with retry instruction.
  ///
  /// In en, this message translates to:
  /// **'Timeout exceeded. Try again.'**
  String get timeoutRetry;

  /// Error message when server response is malformed or invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid server response'**
  String get invalidServerResponse;

  /// Error message for incorrect login credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// Message when user cancels authentication process.
  ///
  /// In en, this message translates to:
  /// **'Connection canceled by user'**
  String get userCanceledConnection;

  /// Message asking user to reconnect when session expired.
  ///
  /// In en, this message translates to:
  /// **'Please reconnect'**
  String get pleaseReconnect;

  /// Error message for profile management operations.
  ///
  /// In en, this message translates to:
  /// **'Error managing user profile'**
  String get profileManagementError;

  /// Error message for general connection problems.
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Check your internet connection'**
  String get connectionProblem;

  /// Generic authentication error message.
  ///
  /// In en, this message translates to:
  /// **'An authentication error occurred'**
  String get authenticationError;

  /// Password strength requirement message.
  ///
  /// In en, this message translates to:
  /// **'The password must contain at least 8 characters with uppercase, lowercase, digit and symbol'**
  String get passwordMustRequired;

  /// Error message when password is too short.
  ///
  /// In en, this message translates to:
  /// **'The password must contain at least 8 characters'**
  String get passwordTooShort;

  /// Error message when user's email is not confirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed. Check your mailbox.'**
  String get notConfirmedEmail;

  /// Message asking user to confirm email before login.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before logging in'**
  String get confirmEmailBeforeLogin;

  /// Error message when trying to register with existing email.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email'**
  String get emailAlreadyUsed;

  /// Error message when password is too simple.
  ///
  /// In en, this message translates to:
  /// **'The password does not meet the security requirements'**
  String get passwordTooSimple;

  /// Message when user session has expired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please reconnect'**
  String get expiredSession;

  /// Error message when profile saving fails.
  ///
  /// In en, this message translates to:
  /// **'Error while saving the profile'**
  String get savingProfileError;

  /// No description provided for @timeAgoAtMoment.
  ///
  /// In en, this message translates to:
  /// **'at the moment'**
  String get timeAgoAtMoment;

  /// No description provided for @timeAgoFallback.
  ///
  /// In en, this message translates to:
  /// **'recent'**
  String get timeAgoFallback;

  /// Label showing the difference of save a route in secondes.
  ///
  /// In en, this message translates to:
  /// **'there are {difference} s'**
  String timaAgoSecondes(int difference);

  /// Label showing the difference of save a route in minutes.
  ///
  /// In en, this message translates to:
  /// **'there are {difference} min'**
  String timaAgoMinutes(int difference);

  /// Label showing the difference of save a route in hours.
  ///
  /// In en, this message translates to:
  /// **'there are {difference} h'**
  String timaAgoHours(int difference);

  /// Indicates how many days have passed, with plural handling for 'day'.
  ///
  /// In en, this message translates to:
  /// **'there are {days} day{days, plural, =1 {} other {s}}'**
  String daysAgoLabel(int days);

  /// Indicates how many days have passed, with plural handling for 'day'.
  ///
  /// In en, this message translates to:
  /// **'Route n°{count}'**
  String routeGenerateName(int count);

  /// Indicates how many days have passed, with plural handling for 'day'.
  ///
  /// In en, this message translates to:
  /// **'Generated on the {date}'**
  String routeGenerateDesc(String date);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'it': return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
