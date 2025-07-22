// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get currentLanguage => 'Español';

  @override
  String get pathGenerated => 'Ruta generada';

  @override
  String get pathLoop => 'Bucle';

  @override
  String get pathSimple => 'Simple';

  @override
  String get start => 'Comenzar';

  @override
  String get share => 'Compartir';

  @override
  String get toTheRun => 'A la carrera';

  @override
  String get pathPoint => 'Punto';

  @override
  String get pathTotal => 'Total';

  @override
  String get pathTime => 'Duración';

  @override
  String get pointsCount => 'Puntos';

  @override
  String get guide => 'GUÍA';

  @override
  String get course => 'RECORRIDO';

  @override
  String get enterDestination => 'Ingresa un destino';

  @override
  String shareMsg(String distance) {
    return 'Mi ruta RunAway de $distance km generada con la aplicación RunAway';
  }

  @override
  String get currentPosition => 'Posición actual';

  @override
  String get retrySmallRay => 'Intenta de nuevo con un radio menor';

  @override
  String get noCoordinateServer => 'No se recibieron coordenadas del servidor';

  @override
  String get generationError => 'Error durante la generación';

  @override
  String get disabledLocation => 'Los servicios de ubicación están deshabilitados.';

  @override
  String get deniedPermission => 'Los permisos de ubicación están denegados.';

  @override
  String get disabledAndDenied => 'Los permisos de ubicación están denegados permanentemente, no podemos solicitar permiso.';

  @override
  String get toTheRouteNavigation => 'Navegación a la ruta detenida';

  @override
  String get completedCourseNavigation => 'Navegación del recorrido completado';

  @override
  String get startingPoint => '¡Punto de partida alcanzado!';

  @override
  String get startingPointNavigation => 'Navegación al punto de partida...';

  @override
  String get arrivedToStartingPoint => '¡Has llegado al punto de partida del recorrido!';

  @override
  String get later => 'Más tarde';

  @override
  String get startCourse => 'Iniciar el recorrido';

  @override
  String get courseStarted => 'Navegación del recorrido iniciada...';

  @override
  String get userAreStartingPoint => 'Estás en el punto de partida del recorrido.';

  @override
  String get error => 'Error';

  @override
  String get routeCalculation => 'Cálculo de la ruta al recorrido...';

  @override
  String get unableCalculateRoute => 'No se puede calcular la ruta al recorrido';

  @override
  String unableStartNavigation(Object error) {
    return 'No se puede iniciar la navegación: $error';
  }

  @override
  String get navigationServiceError => 'El servicio de navegación devolvió falso';

  @override
  String get calculationError => 'Error en el cálculo de ruta';

  @override
  String calculationRouteError(String error) {
    return 'Error en el cálculo de ruta: $error';
  }

  @override
  String get navigationInitializedError => 'Error de navegación (servicio no inicializado)';

  @override
  String get navigationError => 'Error del servicio de navegación';

  @override
  String get retry => 'Intentar de nuevo';

  @override
  String get navigationToCourse => 'Navegación al recorrido';

  @override
  String userToStartingPoint(String distance) {
    return 'Estás a $distance del punto de partida.';
  }

  @override
  String get askUserChooseRoute => '¿Qué quieres hacer?';

  @override
  String get voiceInstructions => 'Navegación con instrucciones de voz';

  @override
  String get cancel => 'Cancelar';

  @override
  String get directPath => 'Ruta directa';

  @override
  String get guideMe => 'Guíame';

  @override
  String get readyToStart => 'Listo para iniciar la navegación del recorrido';

  @override
  String get notAvailablePosition => 'Posición del usuario o ruta no disponible';

  @override
  String get urbanization => 'Nivel de urbanización';

  @override
  String get terrain => 'Tipo de terreno';

  @override
  String get activity => 'Tipo de actividad';

  @override
  String get distance => 'Distancia';

  @override
  String get elevation => 'Desnivel positivo';

  @override
  String get generate => 'Generar';

  @override
  String get advancedOptions => 'Opciones avanzadas';

  @override
  String get loopCourse => 'Recorrido en bucle';

  @override
  String get returnStartingPoint => 'Volver al punto de partida';

  @override
  String get avoidTraffic => 'Evitar tráfico';

  @override
  String get quietStreets => 'Priorizar calles tranquilas';

  @override
  String get scenicRoute => 'Ruta panorámica';

  @override
  String get prioritizeLandscapes => 'Priorizar paisajes hermosos';

  @override
  String get walking => 'Caminar';

  @override
  String get running => 'Correr';

  @override
  String get cycling => 'Ciclismo';

  @override
  String get nature => 'Naturaleza';

  @override
  String get mixedUrbanization => 'Mixto';

  @override
  String get urban => 'Urbano';

  @override
  String get flat => 'Plano';

  @override
  String get mixedTerrain => 'Mixto';

  @override
  String get hilly => 'Montañoso';

  @override
  String get flatDesc => 'Terreno plano con poco desnivel';

  @override
  String get mixedTerrainDesc => 'Terreno variado con desnivel moderado';

  @override
  String get hillyDesc => 'Terreno con pendiente pronunciada';

  @override
  String get natureDesc => 'Principalmente en la naturaleza';

  @override
  String get mixedUrbanizationDesc => 'Mezcla ciudad y naturaleza';

  @override
  String get urbanDesc => 'Principalmente en la ciudad';

  @override
  String get arriveAtDestination => 'Llegas a tu destino';

  @override
  String continueOn(int distance) {
    return 'Continúa derecho por ${distance}m';
  }

  @override
  String followPath(String distance) {
    return 'Sigue el sendero por ${distance}km';
  }

  @override
  String get restrictedAccessTitle => 'Acceso restringido';

  @override
  String get notLoggedIn => 'No has iniciado sesión';

  @override
  String get loginOrCreateAccountHint => 'Para acceder a esta página, por favor inicia sesión o crea una cuenta.';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear una cuenta';

  @override
  String get needHelp => '¿Necesitas ayuda? ';

  @override
  String get createAccountTitle => '¿Listo para la aventura?';

  @override
  String get createAccountSubtitle => 'Crea tu cuenta para descubrir rutas únicas y comenzar a explorar nuevos horizontes deportivos';

  @override
  String get emailHint => 'Dirección de correo electrónico';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get confirmPasswordHint => 'Confirmar contraseña';

  @override
  String get passwordsDontMatchError => 'Las contraseñas no coinciden';

  @override
  String get haveAccount => '¿Tienes una cuenta?';

  @override
  String get termsAndPrivacy => 'Términos de Servicio | Política de Privacidad';

  @override
  String get continueForms => 'Continuar';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get orDivider => 'O';

  @override
  String get loginGreetingTitle => '¡Qué bueno verte de vuelta!';

  @override
  String get loginGreetingSubtitle => 'Por favor ingresa los detalles requeridos.';

  @override
  String get forgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get createAccountQuestion => '¿Crear una cuenta?';

  @override
  String get signUp => 'Registrarse';

  @override
  String get appleLoginTodo => 'Inicio de sesión con Apple – Por implementar';

  @override
  String get googleLoginTodo => 'Inicio de sesión con Google – Por implementar';

  @override
  String get setupAccountTitle => 'Configura tu cuenta';

  @override
  String get onboardingInstruction => 'Por favor completa toda la información presentada abajo para crear tu cuenta.';

  @override
  String get fullNameHint => 'Juan Pérez';

  @override
  String get usernameHint => '@juanperez';

  @override
  String get complete => 'Completar';

  @override
  String get creatingProfile => 'Creando tu perfil...';

  @override
  String get fullNameRequired => 'El nombre completo es requerido';

  @override
  String get fullNameMinLength => 'El nombre debe tener al menos 2 caracteres';

  @override
  String get usernameRequired => 'El nombre de usuario es requerido';

  @override
  String get usernameMinLength => 'El nombre de usuario debe tener al menos 3 caracteres';

  @override
  String get usernameInvalidChars => 'Solo se permiten letras, números y _';

  @override
  String imagePickError(Object error) {
    return 'Error al seleccionar imagen: $error';
  }

  @override
  String get avatarUploadWarning => 'Perfil creado pero no se pudo subir el avatar. Puedes agregarlo más tarde.';

  @override
  String get emailInvalid => 'Dirección de correo electrónico inválida';

  @override
  String get passwordMinLength => 'Al menos 6 caracteres';

  @override
  String get currentGeneration => 'Generación actual...';

  @override
  String get navigationPaused => 'Navegación pausada';

  @override
  String get navigationResumed => 'Navegación reanudada';

  @override
  String get time => 'Tiempo';

  @override
  String get pace => 'Ritmo';

  @override
  String get speed => 'Velocidad';

  @override
  String get elevationGain => 'Ganancia';

  @override
  String get remaining => 'Restante';

  @override
  String get progress => 'Progreso';

  @override
  String get estimatedTime => 'Tiempo est.';

  @override
  String get updatingPhoto => 'Actualizando la foto…';

  @override
  String selectionError(String error) {
    return 'Error durante la selección: $error';
  }

  @override
  String get account => 'Cuenta';

  @override
  String get defaultUserName => 'Usuario';

  @override
  String get preferences => 'Preferencias';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get theme => 'Tema';

  @override
  String get enabled => 'Habilitado';

  @override
  String get lightTheme => 'Claro';

  @override
  String get selectPreferenceTheme => 'Selecciona tu preferencia';

  @override
  String get autoTheme => 'Automático';

  @override
  String get darkTheme => 'Oscuro';

  @override
  String get accountSection => 'Cuenta';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get deleteProfile => 'Eliminar perfil';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get editProfileTodo => 'Edición de perfil – Por implementar';

  @override
  String get logoutTitle => 'Cerrar sesión';

  @override
  String get logoutMessage => 'Usted será desconectado de Trailix, pero todos sus datos y preferencias guardados permanecerán seguros';

  @override
  String get logoutConfirm => 'Cerrar sesión';

  @override
  String get deleteAccountTitle => 'Eliminar cuenta';

  @override
  String get deleteAccountMessage => 'Esto eliminará permanentemente su cuenta de Trailix, así como todas las rutas y preferencias guardadas, esta acción no se puede deshacer';

  @override
  String get deleteAccountWarning => 'Esta acción no se puede deshacer';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteAccountTodo => 'Eliminación de cuenta – Por implementar';

  @override
  String get editPhoto => 'Editar la foto';

  @override
  String get availableLanguage => 'Idioma disponible';

  @override
  String get selectPreferenceLanguage => 'Selecciona tu preferencia';

  @override
  String get activityTitle => 'Actividad';

  @override
  String get exportData => 'Exportar datos';

  @override
  String get resetGoals => 'Restablecer objetivos';

  @override
  String get statisticsCalculation => 'Cálculo de estadísticas...';

  @override
  String get loading => 'Cargando...';

  @override
  String get createGoal => 'Crear un objetivo';

  @override
  String get customGoal => 'Objetivo personalizado';

  @override
  String get createCustomGoal => 'Crear un objetivo personalizado';

  @override
  String get goalsModels => 'Modelos de objetivos';

  @override
  String get predefinedGoals => 'Elige entre objetivos predefinidos';

  @override
  String get updatedGoal => 'Objetivo actualizado';

  @override
  String get createdGoal => 'Objetivo creado';

  @override
  String get deleteGoalTitle => 'Eliminar objetivo';

  @override
  String get deleteGoalMessage => '¿Estás seguro de que quieres eliminar este objetivo?';

  @override
  String get removedGoal => 'Objetivo eliminado';

  @override
  String get goalsResetTitle => 'Restablecer los objetivos';

  @override
  String get goalsResetMessage => 'Esta acción eliminará todos tus objetivos. ¿Estás seguro?';

  @override
  String get reset => 'Restablecer';

  @override
  String get activityFilter => 'Por actividad';

  @override
  String get allFilter => 'Todos';

  @override
  String totalRoutes(int totalRoutes) {
    return '$totalRoutes rutas';
  }

  @override
  String get emptyDataFilter => 'No hay datos para este filtro';

  @override
  String get byActivityFilter => 'Filtrar por actividad';

  @override
  String get typeOfActivity => 'Elige el tipo de actividad';

  @override
  String get allActivities => 'Todas las actividades';

  @override
  String get modifyGoal => 'Modificar objetivo';

  @override
  String get newGoal => 'Nuevo objetivo';

  @override
  String get modify => 'Modificar';

  @override
  String get create => 'Crear';

  @override
  String get goalTitle => 'Título del objetivo';

  @override
  String get titleValidator => 'Debes ingresar un título';

  @override
  String get optionalDescription => 'Descripción (opcional)';

  @override
  String get goalType => 'Tipo de objetivo';

  @override
  String get optionalActivity => 'Actividad (opcional)';

  @override
  String get targetValue => 'Valor objetivo';

  @override
  String get targetValueValidator => 'Por favor ingresa un valor objetivo';

  @override
  String get positiveValueValidator => 'Por favor ingresa un valor positivo';

  @override
  String get optionalDeadline => 'Fecha límite (opcional)';

  @override
  String get selectDate => 'Selecciona una fecha';

  @override
  String get distanceType => 'km';

  @override
  String get routesType => 'rutas';

  @override
  String get speedType => 'km/h';

  @override
  String get elevationType => 'm';

  @override
  String get goalTypeDistance => 'Distancia mensual';

  @override
  String get goalTypeRoutes => 'Número de rutas';

  @override
  String get goalTypeSpeed => 'Velo. promedio';

  @override
  String get goalTypeElevation => 'Ganancia total de elevación';

  @override
  String get monthlyRaceTitle => 'Carrera mensual';

  @override
  String get monthlyRaceMessage => '50km por mes corriendo';

  @override
  String get monthlyRaceGoal => 'Correr 50km por mes';

  @override
  String get weeklyBikeTitle => 'Bicicleta semanal';

  @override
  String get weeklyBikeMessage => '100km por semana en bicicleta';

  @override
  String get weeklyBikeGoal => 'Andar en bicicleta 100km por semana';

  @override
  String get regularTripsTitle => 'Recorridos regulares';

  @override
  String get regularTripsMessage => '10 recorridos por mes';

  @override
  String get regularTripsGoal => 'Completar 10 recorridos por mes';

  @override
  String get mountainChallengeTitle => 'Desafío de montaña';

  @override
  String get mountainChallengeMessage => '1000m de desnivel positivo por mes';

  @override
  String get mountainChallengeGoal => 'Subir 1000m de desnivel positivo por mes';

  @override
  String get averageSpeedTitle => 'Velocidad promedio';

  @override
  String get averageSpeedMessage => 'Mantener 12km/h de promedio';

  @override
  String get averageSpeedGoal => 'Mantener una velocidad promedio de 12km/h';

  @override
  String get personalGoals => 'Objetivos personales';

  @override
  String get add => 'Agregar';

  @override
  String get emptyDefinedGoals => 'No tienes objetivos definidos';

  @override
  String get pressToAdd => 'Presiona + para crear uno';

  @override
  String get personalRecords => 'Récords personales';

  @override
  String get empryPersonalRecords => 'Completa recorridos para establecer tus récords';

  @override
  String get overview => 'Resumen';

  @override
  String get totalDistance => 'Distancia total';

  @override
  String get totalTime => 'Tiempo total';

  @override
  String get confirmRouteDeletionTitle => 'Confirmar la eliminación';

  @override
  String confirmRouteDeletionMessage(String routeName) {
    return '¿Realmente quieres eliminar la ruta $routeName?';
  }

  @override
  String get historic => 'Historial';

  @override
  String get loadingError => 'Error de carga';

  @override
  String get emptySavedRouteTitle => 'Ninguna ruta guardada';

  @override
  String get emptySavedRouteMessage => 'Genera tu primera ruta desde la página principal para verla aparecer aquí';

  @override
  String get generateRoute => 'Generar una ruta';

  @override
  String get route => 'Ruta';

  @override
  String get total => 'Total';

  @override
  String get unsynchronized => 'Sin sincronizar';

  @override
  String get synchronized => 'Sincronizado';

  @override
  String get renameRoute => 'Renombrar';

  @override
  String get synchronizeRoute => 'Sincronizar';

  @override
  String get deleteRoute => 'Eliminar';

  @override
  String get followRoute => 'Seguir';

  @override
  String get imageUnavailable => 'Imagen no disponible';

  @override
  String get mapStyleTitle => 'Tipo de mapa';

  @override
  String get mapStyleSubtitle => 'Elige tu estilo';

  @override
  String get mapStyleStreet => 'Calles';

  @override
  String get mapStyleOutdoor => 'Exterior';

  @override
  String get mapStyleLight => 'Claro';

  @override
  String get mapStyleDark => 'Oscuro';

  @override
  String get mapStyleSatellite => 'Satélite';

  @override
  String get mapStyleHybrid => 'Híbrido';

  @override
  String get fullNameTitle => 'Nombre completo';

  @override
  String get usernameTitle => 'Nombre de usuario';

  @override
  String get nonEditableUsername => 'El nombre de usuario no se puede modificar';

  @override
  String get profileUpdated => 'Perfil actualizado correctamente';

  @override
  String get profileUpdateError => 'Error al actualizar el perfil';

  @override
  String get contactUs => 'Contáctanos.';

  @override
  String get editGoal => 'Editar objetivo';

  @override
  String deadlineValid(String date) {
    return 'Válido hasta el $date';
  }

  @override
  String get download => 'Descargar';

  @override
  String get save => 'Guardar';

  @override
  String get saving => 'Guardando...';

  @override
  String get alreadySaved => 'Ya guardado';

  @override
  String get home => 'Inicio';

  @override
  String get resources => 'Recursos';

  @override
  String get contactSupport => 'Contactar con soporte';

  @override
  String get rateInStore => 'Valorar en la tienda';

  @override
  String get followOnX => 'Seguir a @Trailix';

  @override
  String get supportEmailSubject => 'Problema con tu aplicación';

  @override
  String get supportEmailBody => 'Hola soporte de Trailix,\n\nEstoy teniendo problemas en la aplicación.\n¿Podrían ayudarme a resolver esto?\n\nGracias.';

  @override
  String get insufficientCreditsTitle => 'Créditos insuficientes';

  @override
  String insufficientCreditsDescription(int requiredCredits, String action, int availableCredits) {
    return 'Necesitas $requiredCredits crédito(s) para $action. Actualmente tienes $availableCredits crédito(s).';
  }

  @override
  String get buyCredits => 'Comprar créditos';

  @override
  String get currentCredits => 'Créditos actuales';

  @override
  String get availableCredits => 'Créditos disponibles';

  @override
  String get totalUsed => 'Total utilizado';

  @override
  String get popular => 'Popular';

  @override
  String get buySelectedPlan => 'Comprar este plan';

  @override
  String get selectPlan => 'Selecciona un plan';

  @override
  String get purchaseSimulated => 'Compra simulada';

  @override
  String get purchaseSimulatedDescription => 'En modo de desarrollo, las compras se simulan. ¿Deseas simular esta compra?';

  @override
  String get simulatePurchase => 'Simular compra';

  @override
  String get purchaseSuccess => '¡Compra exitosa!';

  @override
  String get transactionHistory => 'Historial de transacciones';

  @override
  String get noTransactions => 'Aún no hay transacciones';

  @override
  String get yesterday => 'Ayer';

  @override
  String get daysAgo => 'días';

  @override
  String get ok => 'OK';

  @override
  String get creditUsageSuccess => 'Créditos usados con éxito';

  @override
  String get routeGenerationWithCredits => 'Se usará 1 crédito para generar esta ruta';

  @override
  String get creditsRequiredForGeneration => 'Generación de ruta (1 crédito)';

  @override
  String get manageCredits => 'Gestionar mis créditos';

  @override
  String get freeCreditsWelcome => '🎉 ¡Bienvenido! Has recibido 3 créditos gratis para empezar';

  @override
  String creditsLeft(int count) {
    return '$count crédito(s) restante(s)';
  }

  @override
  String get elevationRange => 'Rango de desnivel';

  @override
  String get minElevation => 'Desnivel mínimo';

  @override
  String get maxElevation => 'Desnivel máximo';

  @override
  String get difficulty => 'Dificultad';

  @override
  String get maxIncline => 'Pendiente máxima';

  @override
  String get waypointsCount => 'Puntos de interés';

  @override
  String get points => 'pts';

  @override
  String get surfacePreference => 'Superficie';

  @override
  String get naturalPaths => 'Caminos naturales';

  @override
  String get pavedRoads => 'Carreteras pavimentadas';

  @override
  String get mixed => 'Mixto';

  @override
  String get avoidHighways => 'Evitar autopistas';

  @override
  String get avoidMajorRoads => 'Evitar vías principales';

  @override
  String get prioritizeParks => 'Priorizar parques';

  @override
  String get preferGreenSpaces => 'Preferir espacios verdes';

  @override
  String get elevationLoss => 'Desnivel negativo';

  @override
  String get duration => 'Duración';

  @override
  String get calories => 'Calorías';

  @override
  String get scenic => 'Paisaje';

  @override
  String get maxSlope => 'Pendiente máx.';

  @override
  String get highlights => 'Lugares destacados';

  @override
  String get surfaces => 'Superficies';

  @override
  String get easyDifficultyLevel => 'Fácil';

  @override
  String get moderateDifficultyLevel => 'Moderado';

  @override
  String get hardDifficultyLevel => 'Difícil';

  @override
  String get expertDifficultyLevel => 'Experto';

  @override
  String get asphaltSurfaceTitle => 'Asfalto';

  @override
  String get asphaltSurfaceDesc => 'Prioriza carreteras y aceras pavimentadas';

  @override
  String get mixedSurfaceTitle => 'Mixto';

  @override
  String get mixedSurfaceDesc => 'Mezcla de carreteras y senderos según la ruta';

  @override
  String get naturalSurfaceTitle => 'Natural';

  @override
  String get naturalSurfaceDesc => 'Prioriza senderos naturales';

  @override
  String get searchAdress => 'Buscar una dirección...';

  @override
  String get chooseName => 'Elegir un nombre';

  @override
  String get canModifyLater => 'Podrás modificarlo más tarde';

  @override
  String get routeName => 'Nombre de la ruta';

  @override
  String get limitReachedGenerations => 'Límite alcanzado';

  @override
  String get exhaustedGenerations => 'Generaciones agotadas';

  @override
  String get remainingLimitGenerations => 'Límite restante';

  @override
  String remainingGenerationsLabel(int remainingGenerations) {
    String _temp0 = intl.Intl.pluralLogic(
      remainingGenerations,
      locale: localeName,
      other: 'es',
      one: '',
    );
    return '$remainingGenerations generación gratuita$_temp0';
  }

  @override
  String get freeGenerations => 'Generaciones gratuitas';

  @override
  String get exhaustedFreeGenerations => 'Generaciones gratuitas agotadas';

  @override
  String get exhaustedCredits => 'Créditos agotados';

  @override
  String get authForMoreGenerations => 'Crea una cuenta gratuita para más generaciones';

  @override
  String get createFreeAccount => 'Crear cuenta gratuita';

  @override
  String get exportRouteTitle => 'Exportar la ruta';

  @override
  String get exportRouteDesc => 'Elige el formato de exportación';

  @override
  String get generateInProgress => 'Generando la ruta...';

  @override
  String get emptyRouteForSave => 'No hay ruta para guardar';

  @override
  String get connectionError => 'Error de conexión';

  @override
  String get notAvailableMap => 'Mapa no disponible';

  @override
  String get missingRouteSettings => 'Faltan configuraciones de la ruta';

  @override
  String get savedRoute => 'Ruta guardada';

  @override
  String get loginRequiredTitle => 'Inicio de sesión requerido';

  @override
  String get loginRequiredDesc => 'Debes iniciar sesión para guardar tus rutas';

  @override
  String get reallyContinueTitle => '¿Realmente quieres continuar?';

  @override
  String get reallyContinueDesc => 'Esta acción eliminará la ruta generada previamente, ¡será irrecuperable!';

  @override
  String get generationEmptyLocation => 'No hay ubicación disponible para la generación';

  @override
  String get unableLaunchGeneration => 'No se puede iniciar la generación';

  @override
  String get invalidParameters => 'Parámetros inválidos';

  @override
  String get locationInProgress => 'Localizando...';

  @override
  String get searchingPosition => 'Buscando tu posición';

  @override
  String get trackingError => 'Error de seguimiento';

  @override
  String get enterAuthDetails => 'Ingresa tus datos';

  @override
  String get enterPassword => 'Ingresa una contraseña';

  @override
  String get continueWithEmail => 'Continuar con email';

  @override
  String get passwordVeryWeak => 'Muy débil';

  @override
  String get passwordWeak => 'Débil';

  @override
  String get passwordFair => 'Regular';

  @override
  String get passwordGood => 'Buena';

  @override
  String get passwordStrong => 'Fuerte';

  @override
  String resetEmail(String email) {
    return 'Email de restablecimiento enviado a $email';
  }

  @override
  String get requiredPassword => 'Contraseña requerida';

  @override
  String requiredCountCharacters(int count) {
    return 'Se requieren al menos $count caracteres';
  }

  @override
  String get requiredCapitalLetter => 'Se requiere al menos una letra mayúscula';

  @override
  String get requiredMinusculeLetter => 'Se requiere al menos una letra minúscula';

  @override
  String get requiredDigit => 'Se requiere al menos un dígito';

  @override
  String get requiredSymbol => 'Se requiere al menos un símbolo';

  @override
  String minimumCountCharacters(int count) {
    return 'Mínimo $count caracteres';
  }

  @override
  String get oneCapitalLetter => 'Una letra mayúscula';

  @override
  String get oneMinusculeLetter => 'Una letra minúscula';

  @override
  String get oneDigit => 'Un dígito';

  @override
  String get oneSymbol => 'Un símbolo';

  @override
  String get successEmailSentBack => 'Email de confirmación enviado exitosamente';

  @override
  String get checkEmail => 'Verifica tu email';

  @override
  String successSentConfirmationLink(String email) {
    return 'Hemos enviado un enlace de confirmación a $email. Haz clic en el enlace del email para activar tu cuenta.';
  }

  @override
  String get resendCode => 'Reenviar el código';

  @override
  String resendCodeInDelay(int count) {
    return 'Reenviar en ${count}s';
  }

  @override
  String get loginBack => 'Volver al inicio de sesión';

  @override
  String get requiredEmail => 'Email requerido';

  @override
  String get receiveResetLink => 'Ingresa tu dirección de email para recibir un enlace de restablecimiento';

  @override
  String get send => 'Enviar';

  @override
  String get byDefault => 'Por defecto';

  @override
  String get changePhoto => 'Cambiar foto';

  @override
  String get desiredSelectionMode => 'Antes de continuar, por favor elige el modo de selección deseado';

  @override
  String get cameraMode => 'Cámara';

  @override
  String get galleryMode => 'Galería';

  @override
  String get successUpdatedProfile => 'Perfil actualizado exitosamente';

  @override
  String couldNotLaunchUrl(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String get couldNotLaunchEmailApp => 'No se pudo abrir la aplicación de email';

  @override
  String get userBalance => 'Tu saldo';

  @override
  String get purchasedCredits => 'Comprados';

  @override
  String get usedCredits => 'Usados';

  @override
  String get purchaseCreditsTitle => 'Créditos comprados';

  @override
  String get usageCreditsTitle => 'Crédito para generar una ruta';

  @override
  String get bonusCreditsTitle => 'Créditos de bienvenida gratuitos';

  @override
  String get refundCreditsTitle => 'Créditos restaurados';

  @override
  String get notAvailablePlans => 'Planes no disponibles';

  @override
  String get missingTransactionID => 'ID de transacción faltante';

  @override
  String get purchaseCanceled => 'Compra cancelada';

  @override
  String get unknownError => 'Error desconocido';

  @override
  String get duringPaymentError => 'Error durante el pago';

  @override
  String get networkException => 'Problema de conexión. Por favor intenta de nuevo.';

  @override
  String get retryNotAvailablePlans => 'Plan seleccionado no disponible. Por favor intenta de nuevo.';

  @override
  String get systemIssueDetectedTitle => 'Problema del sistema detectado';

  @override
  String get systemIssueDetectedSubtitle => 'Se ha detectado un problema del sistema. Esto puede ocurrir si las compras anteriores no se completaron correctamente.';

  @override
  String get systemIssueDetectedDesc => 'Reinicia la aplicación e intenta de nuevo';

  @override
  String get close => 'Cerrar';

  @override
  String get cleaningDone => 'Limpieza completada. Intenta de nuevo ahora.';

  @override
  String cleaningError(String error) {
    return 'Error durante la limpieza: $error';
  }

  @override
  String get cleaning => 'Limpiando';

  @override
  String get creditPlanModalTitle => '¡Abastécete de créditos para vivir nuevas aventuras!';

  @override
  String get creditPlanModalSubtitle => 'Elige tu paquete favorito, luego haz clic aquí para comenzar a explorar!';

  @override
  String get creditPlanModalWarning => 'El pago se debita al confirmar la compra. Los créditos no son reembolsables y solo son válidos en la aplicación.';

  @override
  String get refresh => 'Actualizar';

  @override
  String get successRouteDeleted => 'Ruta eliminada exitosamente';

  @override
  String get errorRouteDeleted => 'Error al eliminar';

  @override
  String get displayRouteError => 'Error durante la visualización del recorrido';

  @override
  String get routeNameUpdateException => 'El nombre no puede estar vacío';

  @override
  String get routeNameUpdateExceptionMinCharacters => 'El nombre debe contener al menos 2 caracteres';

  @override
  String get routeNameUpdateExceptionCountCharacters => 'El nombre no puede exceder 50 caracteres';

  @override
  String get routeNameUpdateExceptionForbiddenCharacters => 'El nombre contiene caracteres prohibidos';

  @override
  String get routeNameUpdateDone => 'Actualización completada';

  @override
  String formatRouteExport(String format) {
    return 'Ruta exportada en formato $format';
  }

  @override
  String routeExportError(String error) {
    return 'Error durante la exportación: $error';
  }

  @override
  String get updateRouteNameTitle => 'Actualizar';

  @override
  String get updateRouteNameSubtitle => 'Elige un nuevo nombre';

  @override
  String get updateRouteNameHint => 'Proceso digestivo después de comer';

  @override
  String get initializationError => 'Error de inicialización';

  @override
  String get gpxFormatName => 'Garmin / Komoot...';

  @override
  String get gpxFormatDescription => 'Para exportar en archivo GPX';

  @override
  String get kmlFormatName => 'Google Maps / Earth...';

  @override
  String get kmlFormatDescription => 'Para exportar en archivo KML';

  @override
  String get routeExportedFrom => 'Ruta exportada desde Trailix';

  @override
  String routeDescription(String activityType, String distance) {
    return 'Ruta de $activityType de ${distance}km generada por Trailix';
  }

  @override
  String routeDistanceLabel(String distance) {
    return 'Ruta de ${distance}km';
  }

  @override
  String get endPoint => 'Llegada';

  @override
  String get emptyRouteForExport => 'No hay ruta para exportar';

  @override
  String get serverErrorRetry => 'Error del servidor. Por favor intenta de nuevo más tarde.';

  @override
  String get genericErrorRetry => 'Ha ocurrido un error. Por favor intenta de nuevo.';

  @override
  String get invalidRequest => 'Solicitud inválida';

  @override
  String get serviceUnavailable => 'Servicio temporalmente no disponible. Intenta de nuevo en unos minutos.';

  @override
  String get timeoutError => 'Tiempo de espera agotado. Verifica tu conexión.';

  @override
  String get unexpectedServerError => 'Error inesperado del servidor';

  @override
  String serverErrorCode(int statusCode) {
    return 'Error del servidor ($statusCode)';
  }

  @override
  String get noInternetConnection => 'Sin conexión a internet. Verifica tu red.';

  @override
  String get timeoutRetry => 'Tiempo de espera agotado. Intenta de nuevo.';

  @override
  String get invalidServerResponse => 'Respuesta del servidor inválida';

  @override
  String get invalidCredentials => 'Email o contraseña incorrectos';

  @override
  String get userCanceledConnection => 'Conexión cancelada por el usuario';

  @override
  String get pleaseReconnect => 'Por favor reconéctate';

  @override
  String get profileManagementError => 'Error al gestionar el perfil de usuario';

  @override
  String get connectionProblem => 'Problema de conexión. Verifica tu conexión a internet';

  @override
  String get authenticationError => 'Ha ocurrido un error de autenticación';

  @override
  String get passwordMustRequired => 'La contraseña debe contener al menos 8 caracteres con mayúscula, minúscula, dígito y símbolo';

  @override
  String get passwordTooShort => 'La contraseña debe contener al menos 8 caracteres';

  @override
  String get notConfirmedEmail => 'Email no confirmado. Verifica tu bandeja de entrada.';

  @override
  String get confirmEmailBeforeLogin => 'Por favor confirma tu email antes de iniciar sesión';

  @override
  String get emailAlreadyUsed => 'Ya existe una cuenta con este email';

  @override
  String get passwordTooSimple => 'La contraseña no cumple con los requisitos de seguridad';

  @override
  String get expiredSession => 'Sesión expirada. Por favor reconéctate';

  @override
  String get savingProfileError => 'Error al guardar el perfil';

  @override
  String get timeAgoAtMoment => 'en este momento';

  @override
  String get timeAgoFallback => 'reciente';

  @override
  String timaAgoSecondes(int difference) {
    return 'hace $difference s';
  }

  @override
  String timaAgoMinutes(int difference) {
    return 'hace $difference min';
  }

  @override
  String timaAgoHours(int difference) {
    return 'hace $difference h';
  }

  @override
  String daysAgoLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'hace $days día$_temp0';
  }

  @override
  String routeGenerateName(int count) {
    return 'Ruta n.º $count';
  }

  @override
  String routeGenerateDesc(String date) {
    return 'Generado el $date';
  }
}
