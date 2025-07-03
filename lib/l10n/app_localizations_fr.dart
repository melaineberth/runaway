// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get language => 'Langue';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get currentLanguage => 'Français';

  @override
  String get pathGenerated => 'Parcours généré';

  @override
  String get pathLoop => 'Boucle';

  @override
  String get pathSimple => 'Simple';

  @override
  String get start => 'Commencer';

  @override
  String get share => 'Partager';

  @override
  String get toTheRun => 'Vers la course';

  @override
  String get pathPoint => 'Point';

  @override
  String get pathTotal => 'Total';

  @override
  String get pathTime => 'Durée';

  @override
  String get pointsCount => 'Points';

  @override
  String get guide => 'GUIDE';

  @override
  String get course => 'PARCOURS';

  @override
  String get enterDestination => 'Entrez une destination';

  @override
  String shareMsg(String distance) {
    return 'Mon parcours RunAway de $distance km généré avec l\'app RunAway';
  }

  @override
  String get currentPosition => 'Position actuelle';

  @override
  String get retrySmallRay => 'Réessayez avec un rayon plus petit';

  @override
  String get noCoordinateServer => 'Aucune coordonnée reçue du serveur';

  @override
  String get generationError => 'Erreur lors de la génération';

  @override
  String get disabledLocation => 'Les services de localisation sont désactivés.';

  @override
  String get deniedPermission => 'Les autorisations de localisation sont refusées.';

  @override
  String get disabledAndDenied => 'Les autorisations de localisation sont refusées définitivement, nous ne pouvons pas demander l\'autorisation.';

  @override
  String get toTheRouteNavigation => 'Navigation vers le parcours interrompu';

  @override
  String get completedCourseNavigation => 'Navigation du parcours terminé';

  @override
  String get startingPoint => 'Point de départ atteint !';

  @override
  String get startingPointNavigation => 'Navigation vers le point de départ...';

  @override
  String get arrivedToStartingPoint => 'Vous êtes arrivé au point de départ du parcours !';

  @override
  String get later => 'Plus tard';

  @override
  String get startCourse => 'Commencer le parcours';

  @override
  String get courseStarted => 'Navigation du parcours commencée...';

  @override
  String get userAreStartingPoint => 'Vous êtes au point de départ du parcours.';

  @override
  String get error => 'Erreur';

  @override
  String get routeCalculation => 'Calcul de l\'itinéraire vers le parcours...';

  @override
  String get unableCalculateRoute => 'Impossible de calculer l\'itinéraire vers le parcours';

  @override
  String unableStartNavigation(Object error) {
    return 'Impossible de démarrer la navigation : $error';
  }

  @override
  String get navigationServiceError => 'Le service de navigation a renvoyé false';

  @override
  String get calculationError => 'Erreur de calcul d\'itinéraire';

  @override
  String calculationRouteError(String error) {
    return 'Erreur de calcul d\'itinéraire : $error';
  }

  @override
  String get navigationInitializedError => 'Erreur de navigation (service non initialisé)';

  @override
  String get navigationError => 'Erreur du service de navigation';

  @override
  String get retry => 'Réessayer';

  @override
  String get navigationToCourse => 'Navigation vers le parcours';

  @override
  String userToStartingPoint(String distance) {
    return 'Vous êtes à $distance du point de départ.';
  }

  @override
  String get askUserChooseRoute => 'Que voulez-vous faire ?';

  @override
  String get voiceInstructions => 'Navigation avec instructions vocales';

  @override
  String get cancel => 'Annuler';

  @override
  String get directPath => 'Chemin direct';

  @override
  String get guideMe => 'Me guider';

  @override
  String get readyToStart => 'Prêt à commencer la navigation du parcours';

  @override
  String get notAvailablePosition => 'Position utilisateur ou itinéraire non disponible';

  @override
  String get urbanization => 'Niveau d\'urbanisation';

  @override
  String get terrain => 'Type de terrain';

  @override
  String get activity => 'Type d\'activité';

  @override
  String get distance => 'Distance';

  @override
  String get elevation => 'Dénivelé positif';

  @override
  String get generate => 'Générer';

  @override
  String get advancedOptions => 'Options avancées';

  @override
  String get loopCourse => 'Parcours en boucle';

  @override
  String get returnStartingPoint => 'Retour au point de départ';

  @override
  String get avoidTraffic => 'Éviter le trafic';

  @override
  String get quietStreets => 'Privilégier les rues calmes';

  @override
  String get scenicRoute => 'Parcours pittoresque';

  @override
  String get prioritizeLandscapes => 'Privilégier les beaux paysages';

  @override
  String get walking => 'Marche';

  @override
  String get running => 'Course';

  @override
  String get cycling => 'Vélo';

  @override
  String get nature => 'Nature';

  @override
  String get mixedUrbanization => 'Mixte';

  @override
  String get urban => 'Urbain';

  @override
  String get flat => 'Plat';

  @override
  String get mixedTerrain => 'Mixte';

  @override
  String get hilly => 'Vallonné';

  @override
  String get flatDesc => 'Terrain plat avec peu de dénivelé';

  @override
  String get mixedTerrainDesc => 'Terrain varié avec dénivelé modéré';

  @override
  String get hillyDesc => 'Terrain avec pente prononcée';

  @override
  String get natureDesc => 'Principalement en nature';

  @override
  String get mixedUrbanizationDesc => 'Mélange ville et nature';

  @override
  String get urbanDesc => 'Principalement en ville';

  @override
  String get arriveAtDestination => 'Vous arrivez à votre destination';

  @override
  String continueOn(int distance) {
    return 'Continuez tout droit sur ${distance}m';
  }

  @override
  String followPath(String distance) {
    return 'Suivez le chemin pendant ${distance}km';
  }

  @override
  String get restrictedAccessTitle => 'Accès restreint';

  @override
  String get notLoggedIn => 'Vous n\'êtes pas connecté';

  @override
  String get loginOrCreateAccountHint => 'Pour accéder à cette page, veuillez vous connecter ou créer un compte.';

  @override
  String get logIn => 'Se connecter';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get needHelp => 'Besoin d\'aide ? ';

  @override
  String get createAccountSubtitle => 'Pour créer un compte, fournissez vos détails, vérifiez votre email et définissez un mot de passe.';

  @override
  String get emailHint => 'Adresse email';

  @override
  String get passwordHint => 'Mot de passe';

  @override
  String get confirmPasswordHint => 'Confirmer le mot de passe';

  @override
  String get passwordsDontMatchError => 'Les mots de passe ne correspondent pas';

  @override
  String get haveAccount => 'Avez-vous un compte ?';

  @override
  String get termsAndPrivacy => 'Conditions & Confidentialité';

  @override
  String get continueForms => 'Continuer';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get orDivider => 'OU';

  @override
  String get loginGreetingTitle => 'Salut !';

  @override
  String get loginGreetingSubtitle => 'Veuillez entrer les détails requis.';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get createAccountQuestion => 'Créer un compte ?';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get appleLoginTodo => 'Connexion Apple – À implémenter';

  @override
  String get googleLoginTodo => 'Connexion Google – À implémenter';

  @override
  String get setupAccountTitle => 'Configurer votre compte';

  @override
  String get onboardingInstruction => 'Veuillez compléter toutes les informations présentées ci-dessous pour créer votre compte.';

  @override
  String get fullNameHint => 'Jean Dupont';

  @override
  String get usernameHint => '@jeandupont';

  @override
  String get complete => 'Terminer';

  @override
  String get creatingProfile => 'Création de votre profil...';

  @override
  String get fullNameRequired => 'Le nom complet est requis';

  @override
  String get fullNameMinLength => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get usernameRequired => 'Le nom d\'utilisateur est requis';

  @override
  String get usernameMinLength => 'Le nom d\'utilisateur doit contenir au moins 3 caractères';

  @override
  String get usernameInvalidChars => 'Seules les lettres, les chiffres et _ sont autorisés';

  @override
  String imagePickError(Object error) {
    return 'Erreur lors de la sélection d\'image : $error';
  }

  @override
  String get avatarUploadWarning => 'Profil créé mais l\'avatar n\'a pas pu être téléchargé. Vous pouvez l\'ajouter plus tard.';

  @override
  String get emailInvalid => 'Adresse email invalide';

  @override
  String get passwordMinLength => 'Au moins 6 caractères';

  @override
  String get currentGeneration => 'Génération en cours...';

  @override
  String get navigationPaused => 'Navigation mise en pause';

  @override
  String get navigationResumed => 'Navigation reprise';

  @override
  String get time => 'Temps';

  @override
  String get pace => 'Allure';

  @override
  String get speed => 'Vitesse';

  @override
  String get elevationGain => 'Dénivelé';

  @override
  String get remaining => 'Restant';

  @override
  String get progress => 'Progression';

  @override
  String get estimatedTime => 'Temps est.';

  @override
  String get updatingPhoto => 'Mise à jour de la photo…';

  @override
  String selectionError(String error) {
    return 'Erreur lors de la sélection : $error';
  }

  @override
  String get account => 'Compte';

  @override
  String get defaultUserName => 'Utilisateur';

  @override
  String get preferences => 'Préférences';

  @override
  String get notifications => 'Notifications';

  @override
  String get theme => 'Thème';

  @override
  String get enabled => 'Activé';

  @override
  String get lightTheme => 'Clair';

  @override
  String get selectPreferenceTheme => 'Sélectionnez votre préférence';

  @override
  String get autoTheme => 'Auto';

  @override
  String get darkTheme => 'Sombre';

  @override
  String get accountSection => 'Compte';

  @override
  String get disconnect => 'Se déconnecter';

  @override
  String get deleteProfile => 'Supprimer le profil';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get editProfileTodo => 'Modification du profil – À implémenter';

  @override
  String get logoutTitle => 'Se déconnecter';

  @override
  String get logoutMessage => 'Vous serez déconnecté de Trailix, mais toutes vos données et préférences sauvegardées resteront sécurisées';

  @override
  String get logoutConfirm => 'Se déconnecter';

  @override
  String get deleteAccountTitle => 'Supprimer le compte';

  @override
  String get deleteAccountMessage => 'Cela supprimera définitivement votre compte Trailix ainsi que toutes les routes et préférences sauvegardées, cette action ne peut pas être annulée';

  @override
  String get deleteAccountWarning => 'Cette action ne peut pas être annulée';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAccountTodo => 'Suppression du compte – À implémenter';

  @override
  String get editPhoto => 'Modifier la photo';

  @override
  String get availableLanguage => 'Langue disponible';

  @override
  String get selectPreferenceLanguage => 'Sélectionnez votre préférence';

  @override
  String get activityTitle => 'Activité';

  @override
  String get exportData => 'Exporter les données';

  @override
  String get resetGoals => 'Réinitialiser les objectifs';

  @override
  String get statisticsCalculation => 'Calcul des statistiques...';

  @override
  String get loading => 'Chargement...';

  @override
  String get createGoal => 'Créer un objectif';

  @override
  String get customGoal => 'Objectif personnalisé';

  @override
  String get createCustomGoal => 'Créer un objectif personnalisé';

  @override
  String get goalsModels => 'Modèles d\'objectifs';

  @override
  String get predefinedGoals => 'Choisir parmi les objectifs prédéfinis';

  @override
  String get updatedGoal => 'Objectif mis à jour';

  @override
  String get createdGoal => 'Objectif créé';

  @override
  String get deleteGoalTitle => 'Supprimer l\'objectif';

  @override
  String get deleteGoalMessage => 'Êtes-vous sûr de vouloir supprimer cet objectif ?';

  @override
  String get removedGoal => 'Objectif supprimé';

  @override
  String get goalsResetTitle => 'Réinitialiser les objectifs';

  @override
  String get goalsResetMessage => 'Cette action supprimera tous vos objectifs. Êtes-vous sûr ?';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get activityFilter => 'Par activité';

  @override
  String get allFilter => 'Tout';

  @override
  String totalRoutes(int totalRoutes) {
    return '$totalRoutes parcours';
  }

  @override
  String get emptyDataFilter => 'Aucune donnée pour ce filtre';

  @override
  String get byActivityFilter => 'Filtrer par activité';

  @override
  String get typeOfActivity => 'Choisir le type d\'activité';

  @override
  String get allActivities => 'Toutes les activités';

  @override
  String get modifyGoal => 'Modifier l\'objectif';

  @override
  String get newGoal => 'Nouvel objectif';

  @override
  String get modify => 'Modifier';

  @override
  String get create => 'Créer';

  @override
  String get goalTitle => 'Titre de l\'objectif';

  @override
  String get titleValidator => 'Vous devez entrer un titre';

  @override
  String get optionalDescription => 'Description (optionnelle)';

  @override
  String get goalType => 'Type d\'objectif';

  @override
  String get optionalActivity => 'Activité (optionnelle)';

  @override
  String get targetValue => 'Valeur cible';

  @override
  String get targetValueValidator => 'Veuillez entrer une valeur cible';

  @override
  String get positiveValueValidator => 'Veuillez entrer une valeur positive';

  @override
  String get optionalDeadline => 'Échéance (optionnelle)';

  @override
  String get selectDate => 'Sélectionner une date';

  @override
  String get distanceType => 'km';

  @override
  String get routesType => 'parcours';

  @override
  String get speedType => 'km/h';

  @override
  String get elevationType => 'm';

  @override
  String get goalTypeDistance => 'Distance mensuelle';

  @override
  String get goalTypeRoutes => 'Nombre de parcours';

  @override
  String get goalTypeSpeed => 'Vitesse moy.';

  @override
  String get goalTypeElevation => 'Dénivelé total';

  @override
  String get monthlyRaceTitle => 'Course mensuelle';

  @override
  String get monthlyRaceMessage => '50km par mois de course';

  @override
  String get monthlyRaceGoal => 'Courir 50km par mois';

  @override
  String get weeklyBikeTitle => 'Vélo hebdomadaire';

  @override
  String get weeklyBikeMessage => '100km par semaine à vélo';

  @override
  String get weeklyBikeGoal => 'Faire 100km de vélo par semaine';

  @override
  String get regularTripsTitle => 'Parcours réguliers';

  @override
  String get regularTripsMessage => '10 parcours par mois';

  @override
  String get regularTripsGoal => 'Compléter 10 parcours par mois';

  @override
  String get mountainChallengeTitle => 'Défi montagne';

  @override
  String get mountainChallengeMessage => '1000m de dénivelé par mois';

  @override
  String get mountainChallengeGoal => 'Gravir 1000m de dénivelé par mois';

  @override
  String get averageSpeedTitle => 'Vitesse moyenne';

  @override
  String get averageSpeedMessage => 'Maintenir 12km/h de moyenne';

  @override
  String get averageSpeedGoal => 'Maintenir une vitesse moyenne de 12km/h';

  @override
  String get personalGoals => 'Objectifs personnels';

  @override
  String get add => 'Ajouter';

  @override
  String get emptyDefinedGoals => 'Vous n\'avez aucun objectif défini';

  @override
  String get pressToAdd => 'Appuyez sur + pour en créer un';

  @override
  String get personalRecords => 'Records personnels';

  @override
  String get empryPersonalRecords => 'Complétez des parcours pour établir vos records';

  @override
  String get overview => 'Aperçu';

  @override
  String get totalDistance => 'Distance totale';

  @override
  String get totalTime => 'Temps total';

  @override
  String get confirmRouteDeletionTitle => 'Confirmer la suppression';

  @override
  String confirmRouteDeletionMessage(String routeName) {
    return 'Voulez-vous vraiment supprimer le parcours $routeName ?';
  }

  @override
  String get historic => 'Trajet';

  @override
  String get loadingError => 'Erreur de chargement';

  @override
  String get emptySavedRouteTitle => 'Aucun parcours sauvegardé';

  @override
  String get emptySavedRouteMessage => 'Générez votre premier parcours depuis l\'accueil pour le voir apparaître ici';

  @override
  String get generateRoute => 'Générer un parcours';

  @override
  String get route => 'Parcours';

  @override
  String get total => 'Total';

  @override
  String get unsynchronized => 'Non sync';

  @override
  String get synchronized => 'Sync';

  @override
  String get renameRoute => 'Renommer';

  @override
  String get synchronizeRoute => 'Synchroniser';

  @override
  String get deleteRoute => 'Supprimer';

  @override
  String get followRoute => 'Suivre';

  @override
  String get imageUnavailable => 'Image indisponible';

  @override
  String get mapStyleTitle => 'Type de carte';

  @override
  String get mapStyleSubtitle => 'Choisissez votre style';

  @override
  String get mapStyleStreet => 'Rue';

  @override
  String get mapStyleOutdoor => 'Extérieur';

  @override
  String get mapStyleLight => 'Clair';

  @override
  String get mapStyleDark => 'Sombre';

  @override
  String get mapStyleSatellite => 'Satellite';

  @override
  String get mapStyleHybrid => 'Hybride';

  @override
  String get fullNameTitle => 'Nom complet';

  @override
  String get usernameTitle => 'Nom d\'utilisateur';

  @override
  String get nonEditableUsername => 'Le nom d\'utilisateur ne peut pas être modifié';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès';

  @override
  String get profileUpdateError => 'Erreur lors de la mise à jour du profil';

  @override
  String get contactUs => 'Contactez-nous.';

  @override
  String get editGoal => 'Modifier l\'objectif';

  @override
  String deadlineValid(String date) {
    return 'Valable jusqu\'au $date';
  }

  @override
  String get download => 'Télécharger';

  @override
  String get save => 'Enregistrer';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get alreadySaved => 'Déjà enregistré';

  @override
  String get home => 'Accueil';

  @override
  String get resources => 'Ressources';

  @override
  String get contactSupport => 'Contacter le support';

  @override
  String get rateInStore => 'Noter dans la boutique';

  @override
  String get followOnX => 'Suivre @Trailix';

  @override
  String get supportEmailSubject => 'Problème avec votre application';

  @override
  String get supportEmailBody => 'Bonjour le support Trailix,\n\nJ\'ai des difficultés avec l\'application.\nPourriez-vous m\'aider à résoudre ce problème ?\n\nMerci.';
}
