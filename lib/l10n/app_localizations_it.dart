// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get language => 'Lingua';

  @override
  String get selectLanguage => 'Seleziona lingua';

  @override
  String get currentLanguage => 'Italiano';

  @override
  String get pathGenerated => 'Percorso generato';

  @override
  String get pathLoop => 'Anello';

  @override
  String get pathSimple => 'Semplice';

  @override
  String get start => 'Inizia';

  @override
  String get share => 'Condividi';

  @override
  String get toTheRun => 'Alla corsa';

  @override
  String get pathPoint => 'Punto';

  @override
  String get pathTotal => 'Totale';

  @override
  String get pathTime => 'Durata';

  @override
  String get pointsCount => 'Punti';

  @override
  String get guide => 'GUIDA';

  @override
  String get course => 'PERCORSO';

  @override
  String get enterDestination => 'Inserisci una destinazione';

  @override
  String shareMsg(String distance) {
    return 'Il mio percorso RunAway di $distance km generato con l\'app RunAway';
  }

  @override
  String get currentPosition => 'Posizione attuale';

  @override
  String get retrySmallRay => 'Riprova con un raggio più piccolo';

  @override
  String get noCoordinateServer => 'Nessuna coordinata ricevuta dal server';

  @override
  String get generationError => 'Errore durante la generazione';

  @override
  String get disabledLocation => 'I servizi di localizzazione sono disabilitati.';

  @override
  String get deniedPermission => 'I permessi di localizzazione sono negati.';

  @override
  String get disabledAndDenied => 'I permessi di localizzazione sono negati permanentemente, non possiamo richiedere l\'autorizzazione.';

  @override
  String get toTheRouteNavigation => 'Navigazione verso il percorso interrotto';

  @override
  String get completedCourseNavigation => 'Navigazione del percorso completato';

  @override
  String get startingPoint => 'Punto di partenza raggiunto!';

  @override
  String get startingPointNavigation => 'Navigazione verso il punto di partenza...';

  @override
  String get arrivedToStartingPoint => 'Sei arrivato al punto di partenza del percorso!';

  @override
  String get later => 'Più tardi';

  @override
  String get startCourse => 'Inizia il percorso';

  @override
  String get courseStarted => 'Navigazione del percorso iniziata...';

  @override
  String get userAreStartingPoint => 'Sei al punto di partenza del percorso.';

  @override
  String get error => 'Errore';

  @override
  String get routeCalculation => 'Calcolo del percorso verso il tracciato...';

  @override
  String get unableCalculateRoute => 'Impossibile calcolare il percorso verso il tracciato';

  @override
  String unableStartNavigation(Object error) {
    return 'Impossibile avviare la navigazione: $error';
  }

  @override
  String get navigationServiceError => 'Il servizio di navigazione ha restituito false';

  @override
  String get calculationError => 'Errore nel calcolo del percorso';

  @override
  String calculationRouteError(String error) {
    return 'Errore nel calcolo del percorso: $error';
  }

  @override
  String get navigationInitializedError => 'Errore di navigazione (servizio non inizializzato)';

  @override
  String get navigationError => 'Errore del servizio di navigazione';

  @override
  String get retry => 'Riprova';

  @override
  String get navigationToCourse => 'Navigazione verso il percorso';

  @override
  String userToStartingPoint(String distance) {
    return 'Sei a $distance dal punto di partenza.';
  }

  @override
  String get askUserChooseRoute => 'Cosa vuoi fare?';

  @override
  String get voiceInstructions => 'Navigazione con istruzioni vocali';

  @override
  String get cancel => 'Annulla';

  @override
  String get directPath => 'Percorso diretto';

  @override
  String get guideMe => 'Guidami';

  @override
  String get readyToStart => 'Pronto per iniziare la navigazione del percorso';

  @override
  String get notAvailablePosition => 'Posizione utente o percorso non disponibile';

  @override
  String get urbanization => 'Livello di urbanizzazione';

  @override
  String get terrain => 'Tipo di terreno';

  @override
  String get activity => 'Tipo di attività';

  @override
  String get distance => 'Distanza';

  @override
  String get elevation => 'Dislivello';

  @override
  String get generate => 'Genera';

  @override
  String get advancedOptions => 'Opzioni avanzate';

  @override
  String get loopCourse => 'Percorso ad anello';

  @override
  String get returnStartingPoint => 'Ritorna al punto di partenza';

  @override
  String get avoidTraffic => 'Evita il traffico';

  @override
  String get quietStreets => 'Privilegia strade tranquille';

  @override
  String get scenicRoute => 'Percorso panoramico';

  @override
  String get prioritizeLandscapes => 'Privilegia paesaggi belli';

  @override
  String get walking => 'Camminata';

  @override
  String get running => 'Corsa';

  @override
  String get cycling => 'Ciclismo';

  @override
  String get nature => 'Natura';

  @override
  String get mixedUrbanization => 'Misto';

  @override
  String get urban => 'Urbano';

  @override
  String get flat => 'Pianeggiante';

  @override
  String get mixedTerrain => 'Misto';

  @override
  String get hilly => 'Collinare';

  @override
  String get flatDesc => 'Terreno pianeggiante con poco dislivello';

  @override
  String get mixedTerrainDesc => 'Terreno vario con dislivello moderato';

  @override
  String get hillyDesc => 'Terreno con pendenze ripide';

  @override
  String get natureDesc => 'Principalmente nella natura';

  @override
  String get mixedUrbanizationDesc => 'Mescola città e natura';

  @override
  String get urbanDesc => 'Principalmente in città';

  @override
  String get arriveAtDestination => 'Arrivi alla tua destinazione';

  @override
  String continueOn(int distance) {
    return 'Continua dritto per ${distance}m';
  }

  @override
  String followPath(String distance) {
    return 'Segui il sentiero per ${distance}km';
  }

  @override
  String get restrictedAccessTitle => 'Accesso limitato';

  @override
  String get notLoggedIn => 'Non sei connesso';

  @override
  String get loginOrCreateAccountHint => 'Per accedere a questa pagina, effettua il login o crea un account.';

  @override
  String get logIn => 'Accedi';

  @override
  String get createAccount => 'Crea un account';

  @override
  String get needHelp => 'Hai bisogno di aiuto? ';

  @override
  String get createAccountTitle => 'Pronto per l\'avventura?';

  @override
  String get createAccountSubtitle => 'Crea il tuo account per scoprire percorsi unici e iniziare ad esplorare nuovi orizzonti sportivi';

  @override
  String get emailHint => 'Indirizzo email';

  @override
  String get passwordHint => 'Password';

  @override
  String get confirmPasswordHint => 'Conferma password';

  @override
  String get passwordsDontMatchError => 'Le password non corrispondono';

  @override
  String get haveAccount => 'Hai un account?';

  @override
  String get termsAndPrivacy => 'Termini di servizio | Informativa sulla privacy';

  @override
  String get continueForms => 'Continua';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get orDivider => 'OPPURE';

  @override
  String get loginGreetingTitle => 'Bello rivederti!';

  @override
  String get loginGreetingSubtitle => 'Inserisci i dettagli richiesti.';

  @override
  String get forgotPassword => 'Password dimenticata?';

  @override
  String get createAccountQuestion => 'Creare un account?';

  @override
  String get signUp => 'Registrati';

  @override
  String get appleLoginTodo => 'Login Apple – Da implementare';

  @override
  String get googleLoginTodo => 'Login Google – Da implementare';

  @override
  String get setupAccountTitle => 'Configura il tuo account';

  @override
  String get onboardingInstruction => 'Completa tutte le informazioni presentate qui sotto per creare il tuo account.';

  @override
  String get fullNameHint => 'Mario Rossi';

  @override
  String get usernameHint => '@mariorossi';

  @override
  String get complete => 'Completa';

  @override
  String get creatingProfile => 'Creando il tuo profilo...';

  @override
  String get fullNameRequired => 'Il nome completo è obbligatorio';

  @override
  String get fullNameMinLength => 'Il nome deve avere almeno 2 caratteri';

  @override
  String get usernameRequired => 'Il nome utente è obbligatorio';

  @override
  String get usernameMinLength => 'Il nome utente deve avere almeno 3 caratteri';

  @override
  String get usernameInvalidChars => 'Solo lettere, numeri e _ sono consentiti';

  @override
  String imagePickError(Object error) {
    return 'Errore nella selezione dell\'immagine: $error';
  }

  @override
  String get avatarUploadWarning => 'Profilo creato ma l\'avatar non è stato caricato. Puoi aggiungerlo in seguito.';

  @override
  String get emailInvalid => 'Indirizzo email non valido';

  @override
  String get passwordMinLength => 'Almeno 6 caratteri';

  @override
  String get currentGeneration => 'Generazione in corso...';

  @override
  String get navigationPaused => 'Navigazione in pausa';

  @override
  String get navigationResumed => 'Navigazione ripresa';

  @override
  String get time => 'Tempo';

  @override
  String get pace => 'Ritmo';

  @override
  String get speed => 'Velocità';

  @override
  String get elevationGain => 'Dislivello';

  @override
  String get remaining => 'Rimanente';

  @override
  String get progress => 'Progresso';

  @override
  String get estimatedTime => 'Tempo stim.';

  @override
  String get updatingPhoto => 'Aggiornamento della foto…';

  @override
  String selectionError(String error) {
    return 'Errore durante la selezione: $error';
  }

  @override
  String get account => 'Account';

  @override
  String get defaultUserName => 'Utente';

  @override
  String get preferences => 'Preferenze';

  @override
  String get notifications => 'Notifiche';

  @override
  String get theme => 'Tema';

  @override
  String get enabled => 'Abilitato';

  @override
  String get lightTheme => 'Chiaro';

  @override
  String get selectPreferenceTheme => 'Seleziona la tua preferenza';

  @override
  String get autoTheme => 'Auto';

  @override
  String get darkTheme => 'Scuro';

  @override
  String get accountSection => 'Account';

  @override
  String get disconnect => 'Disconnetti';

  @override
  String get deleteProfile => 'Elimina profilo';

  @override
  String get editProfile => 'Modifica profilo';

  @override
  String get editProfileTodo => 'Modifica profilo – Da implementare';

  @override
  String get logoutTitle => 'Disconnetti';

  @override
  String get logoutMessage => 'Sarai disconnesso da Trailix, ma tutti i tuoi dati e le tue preferenze salvate rimarranno al sicuro';

  @override
  String get logoutConfirm => 'Disconnetti';

  @override
  String get deleteAccountTitle => 'Elimina account';

  @override
  String get deleteAccountMessage => 'Questo eliminerà definitivamente il tuo account Trailix e tutti i percorsi e le preferenze salvate, questa azione non può essere annullata';

  @override
  String get deleteAccountWarning => 'Questa azione non può essere annullata';

  @override
  String get delete => 'Elimina';

  @override
  String get deleteAccountTodo => 'Eliminazione account – Da implementare';

  @override
  String get editPhoto => 'Modifica la foto';

  @override
  String get availableLanguage => 'Lingua disponibile';

  @override
  String get selectPreferenceLanguage => 'Seleziona la tua preferenza';

  @override
  String get activityTitle => 'Attività';

  @override
  String get exportData => 'Esporta dati';

  @override
  String get resetGoals => 'Reimposta obiettivi';

  @override
  String get statisticsCalculation => 'Calcolo delle statistiche...';

  @override
  String get loading => 'Caricamento...';

  @override
  String get createGoal => 'Crea un obiettivo';

  @override
  String get customGoal => 'Obiettivo personalizzato';

  @override
  String get createCustomGoal => 'Crea un obiettivo personalizzato';

  @override
  String get goalsModels => 'Modelli di obiettivi';

  @override
  String get predefinedGoals => 'Scegli tra obiettivi predefiniti';

  @override
  String get updatedGoal => 'Obiettivo aggiornato';

  @override
  String get createdGoal => 'Obiettivo creato';

  @override
  String get deleteGoalTitle => 'Elimina obiettivo';

  @override
  String get deleteGoalMessage => 'Sei sicuro di voler eliminare questo obiettivo?';

  @override
  String get removedGoal => 'Obiettivo rimosso';

  @override
  String get goalsResetTitle => 'Reimposta gli obiettivi';

  @override
  String get goalsResetMessage => 'Questa azione rimuoverà tutti i tuoi obiettivi. Sei sicuro?';

  @override
  String get reset => 'Reimposta';

  @override
  String get activityFilter => 'Per attività';

  @override
  String get allFilter => 'Tutto';

  @override
  String totalRoutes(int totalRoutes) {
    return '$totalRoutes percorsi';
  }

  @override
  String get emptyDataFilter => 'Nessun dato per questo filtro';

  @override
  String get byActivityFilter => 'Filtra per attività';

  @override
  String get typeOfActivity => 'Scegli il tipo di attività';

  @override
  String get allActivities => 'Tutte le attività';

  @override
  String get modifyGoal => 'Modifica obiettivo';

  @override
  String get newGoal => 'Nuovo obiettivo';

  @override
  String get modify => 'Modifica';

  @override
  String get create => 'Crea';

  @override
  String get goalTitle => 'Titolo obiettivo';

  @override
  String get titleValidator => 'Dovresti inserire un titolo';

  @override
  String get optionalDescription => 'Descrizione (opzionale)';

  @override
  String get goalType => 'Tipo di obiettivo';

  @override
  String get optionalActivity => 'Attività (opzionale)';

  @override
  String get targetValue => 'Valore target';

  @override
  String get targetValueValidator => 'Inserisci un valore target';

  @override
  String get positiveValueValidator => 'Inserisci un valore positivo';

  @override
  String get optionalDeadline => 'Scadenza (opzionale)';

  @override
  String get selectDate => 'Seleziona una data';

  @override
  String get distanceType => 'km';

  @override
  String get routesType => 'percorsi';

  @override
  String get speedType => 'km/h';

  @override
  String get elevationType => 'm';

  @override
  String get goalTypeDistance => 'Distanza mensile';

  @override
  String get goalTypeRoutes => 'Numero di percorsi';

  @override
  String get goalTypeSpeed => 'Velo. media';

  @override
  String get goalTypeElevation => 'Dislivello totale';

  @override
  String get monthlyRaceTitle => 'Corsa mensile';

  @override
  String get monthlyRaceMessage => '50km al mese di corsa';

  @override
  String get monthlyRaceGoal => 'Corri 50km al mese';

  @override
  String get weeklyBikeTitle => 'Bici settimanale';

  @override
  String get weeklyBikeMessage => '100km a settimana in bici';

  @override
  String get weeklyBikeGoal => 'Pedala per 100km a settimana';

  @override
  String get regularTripsTitle => 'Percorsi regolari';

  @override
  String get regularTripsMessage => '10 percorsi al mese';

  @override
  String get regularTripsGoal => 'Completa 10 percorsi al mese';

  @override
  String get mountainChallengeTitle => 'Sfida Montagna';

  @override
  String get mountainChallengeMessage => '1000m di dislivello al mese';

  @override
  String get mountainChallengeGoal => 'Scala 1000m di dislivello al mese';

  @override
  String get averageSpeedTitle => 'Velocità media';

  @override
  String get averageSpeedMessage => 'Mantieni 12km/h di media';

  @override
  String get averageSpeedGoal => 'Mantieni una velocità media di 12km/h';

  @override
  String get personalGoals => 'Obiettivi personali';

  @override
  String get add => 'Aggiungi';

  @override
  String get emptyDefinedGoals => 'Non hai obiettivi definiti';

  @override
  String get pressToAdd => 'Premi + per crearne uno';

  @override
  String get personalRecords => 'Record personali';

  @override
  String get empryPersonalRecords => 'Completa i percorsi per stabilire i tuoi record';

  @override
  String get overview => 'Panoramica';

  @override
  String get totalDistance => 'Distanza totale';

  @override
  String get totalTime => 'Tempo totale';

  @override
  String get confirmRouteDeletionTitle => 'Conferma l\'eliminazione';

  @override
  String confirmRouteDeletionMessage(String routeName) {
    return 'Vuoi davvero eliminare il percorso $routeName?';
  }

  @override
  String get historic => 'Storico';

  @override
  String get loadingError => 'Errore di caricamento';

  @override
  String get emptySavedRouteTitle => 'Nessun percorso salvato';

  @override
  String get emptySavedRouteMessage => 'Genera il tuo primo percorso dalla homepage per vederlo apparire qui';

  @override
  String get generateRoute => 'Genera un percorso';

  @override
  String get route => 'Percorso';

  @override
  String get total => 'Totale';

  @override
  String get unsynchronized => 'Non sinc';

  @override
  String get synchronized => 'Sinc';

  @override
  String get renameRoute => 'Rinomina';

  @override
  String get synchronizeRoute => 'Sincronizza';

  @override
  String get deleteRoute => 'Elimina';

  @override
  String get followRoute => 'Segui';

  @override
  String get imageUnavailable => 'Immagine non disponibile';

  @override
  String get mapStyleTitle => 'Tipo di mappa';

  @override
  String get mapStyleSubtitle => 'Scegli il tuo stile';

  @override
  String get mapStyleStreet => 'Stradale';

  @override
  String get mapStyleOutdoor => 'Outdoor';

  @override
  String get mapStyleLight => 'Chiaro';

  @override
  String get mapStyleDark => 'Scuro';

  @override
  String get mapStyleSatellite => 'Satellite';

  @override
  String get mapStyleHybrid => 'Ibrido';

  @override
  String get fullNameTitle => 'Nome completo';

  @override
  String get usernameTitle => 'Nome utente';

  @override
  String get nonEditableUsername => 'Il nome utente non può essere modificato';

  @override
  String get profileUpdated => 'Profilo aggiornato con successo';

  @override
  String get profileUpdateError => 'Errore durante l\'aggiornamento del profilo';

  @override
  String get contactUs => 'Contattaci.';

  @override
  String get editGoal => 'Modifica obiettivo';

  @override
  String deadlineValid(String date) {
    return 'Valido fino al $date';
  }

  @override
  String get download => 'Scarica';

  @override
  String get save => 'Salva';

  @override
  String get saving => 'Salvataggio in corso…';

  @override
  String get alreadySaved => 'Già salvato';

  @override
  String get home => 'Home';

  @override
  String get resources => 'Risorse';

  @override
  String get contactSupport => 'Contatta il supporto';

  @override
  String get rateInStore => 'Valuta nello store';

  @override
  String get followOnX => 'Segui @Trailix';

  @override
  String get supportEmailSubject => 'Problema con la tua app';

  @override
  String get supportEmailBody => 'Ciao supporto Trailix,\n\nSto avendo problemi nell\'app.\nPotreste aiutarmi a risolvere questo?\n\nGrazie.';

  @override
  String get insufficientCreditsTitle => 'Crediti insufficienti';

  @override
  String insufficientCreditsDescription(int requiredCredits, String action, int availableCredits) {
    return 'Hai bisogno di $requiredCredits credito/i per $action. Al momento hai $availableCredits credito/i.';
  }

  @override
  String get buyCredits => 'Acquista crediti';

  @override
  String get currentCredits => 'Crediti attuali';

  @override
  String get availableCredits => 'Crediti disponibili';

  @override
  String get totalUsed => 'Totale utilizzato';

  @override
  String get popular => 'Popolare';

  @override
  String get buySelectedPlan => 'Acquista questo piano';

  @override
  String get selectPlan => 'Seleziona un piano';

  @override
  String get purchaseSimulated => 'Acquisto simulato';

  @override
  String get purchaseSimulatedDescription => 'In modalità sviluppo, gli acquisti sono simulati. Vuoi simulare questo acquisto?';

  @override
  String get simulatePurchase => 'Simula acquisto';

  @override
  String get purchaseSuccess => 'Acquisto riuscito!';

  @override
  String get transactionHistory => 'Storico delle transazioni';

  @override
  String get noTransactions => 'Nessuna transazione al momento';

  @override
  String get yesterday => 'Ieri';

  @override
  String get daysAgo => 'giorni';

  @override
  String get ok => 'OK';

  @override
  String get creditUsageSuccess => 'Crediti utilizzati con successo';

  @override
  String get routeGenerationWithCredits => 'Verrà utilizzato 1 credito per generare questo percorso';

  @override
  String get creditsRequiredForGeneration => 'Generazione percorso (1 credito)';

  @override
  String get manageCredits => 'Gestisci i miei crediti';

  @override
  String get freeCreditsWelcome => '🎉 Benvenuto! Hai ricevuto 3 crediti gratuiti per iniziare';

  @override
  String creditsLeft(int count) {
    return '$count credito/i rimanente/i';
  }

  @override
  String get elevationRange => 'Intervallo di dislivello';

  @override
  String get minElevation => 'Dislivello minimo';

  @override
  String get maxElevation => 'Dislivello massimo';

  @override
  String get difficulty => 'Difficoltà';

  @override
  String get maxIncline => 'Pendenza massima';

  @override
  String get waypointsCount => 'Punti di interesse';

  @override
  String get points => 'pts';

  @override
  String get surfacePreference => 'Superficie';

  @override
  String get naturalPaths => 'Sentieri naturali';

  @override
  String get pavedRoads => 'Strade asfaltate';

  @override
  String get mixed => 'Misto';

  @override
  String get avoidHighways => 'Evitare autostrade';

  @override
  String get avoidMajorRoads => 'Evitare strade principali';

  @override
  String get prioritizeParks => 'Dare priorità ai parchi';

  @override
  String get preferGreenSpaces => 'Preferire aree verdi';

  @override
  String get elevationLoss => 'Dislivello negativo';

  @override
  String get duration => 'Durata';

  @override
  String get calories => 'Calorie';

  @override
  String get scenic => 'Panoramico';

  @override
  String get maxSlope => 'Pendenza max';

  @override
  String get highlights => 'Punti salienti';

  @override
  String get surfaces => 'Superfici';

  @override
  String get easyDifficultyLevel => 'Facile';

  @override
  String get moderateDifficultyLevel => 'Moderato';

  @override
  String get hardDifficultyLevel => 'Difficile';

  @override
  String get expertDifficultyLevel => 'Esperto';

  @override
  String get asphaltSurfaceTitle => 'Asfalto';

  @override
  String get asphaltSurfaceDesc => 'Privilegia strade e marciapiedi asfaltati';

  @override
  String get mixedSurfaceTitle => 'Misto';

  @override
  String get mixedSurfaceDesc => 'Mix di strade e sentieri a seconda del percorso';

  @override
  String get naturalSurfaceTitle => 'Naturale';

  @override
  String get naturalSurfaceDesc => 'Privilegia sentieri naturali';

  @override
  String get searchAdress => 'Cerca un indirizzo...';

  @override
  String get chooseName => 'Scegli un nome';

  @override
  String get canModifyLater => 'Puoi modificarlo in seguito';

  @override
  String get routeName => 'Nome del percorso';

  @override
  String get limitReachedGenerations => 'Limite raggiunto';

  @override
  String get exhaustedGenerations => 'Generazioni esaurite';

  @override
  String get remainingLimitGenerations => 'Limite rimanente';

  @override
  String remainingGenerationsLabel(int remainingGenerations) {
    String _temp0 = intl.Intl.pluralLogic(
      remainingGenerations,
      locale: localeName,
      other: 'i',
      one: '',
    );
    return '$remainingGenerations generazione gratuita$_temp0';
  }

  @override
  String get freeGenerations => 'Generazioni gratuite';

  @override
  String get exhaustedFreeGenerations => 'Generazioni gratuite esaurite';

  @override
  String get exhaustedCredits => 'Crediti esauriti';

  @override
  String get authForMoreGenerations => 'Crea un account gratuito per altre generazioni';

  @override
  String get createFreeAccount => 'Crea account gratuito';

  @override
  String get exportRouteTitle => 'Esporta il percorso';

  @override
  String get exportRouteDesc => 'Scegli il formato di esportazione';

  @override
  String get generateInProgress => 'Generazione del percorso in corso...';

  @override
  String get emptyRouteForSave => 'Nessun percorso da salvare';

  @override
  String get connectionError => 'Errore di connessione';

  @override
  String get notAvailableMap => 'Mappa non disponibile';

  @override
  String get missingRouteSettings => 'Impostazioni del percorso mancanti';

  @override
  String get savedRoute => 'Percorso salvato';

  @override
  String get loginRequiredTitle => 'Accesso richiesto';

  @override
  String get loginRequiredDesc => 'Devi effettuare l\'accesso per salvare i tuoi percorsi';

  @override
  String get reallyContinueTitle => 'Vuoi davvero continuare?';

  @override
  String get reallyContinueDesc => 'Questa azione eliminerà il percorso generato in precedenza, sarà irrecuperabile!';

  @override
  String get generationEmptyLocation => 'Nessuna posizione disponibile per la generazione';

  @override
  String get unableLaunchGeneration => 'Impossibile avviare la generazione';

  @override
  String get invalidParameters => 'Parametri non validi';
}
