import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  File? _avatar;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    
    // Charger les suggestions depuis les données sociales
    _loadSocialSuggestions();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Suggestions sociales
  Future<void> _loadSocialSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
    });
    
    try {
      final authBloc = context.authBloc;
      
      // Récupérer les informations sociales via le BLoC
      final socialInfo = authBloc.getSocialUserInfo();
      
      // Suggérer le nom complet
      final suggestedFullName = socialInfo['fullName'];
      if (suggestedFullName != null && suggestedFullName.trim().isNotEmpty) {
        _fullNameController.text = suggestedFullName.trim();
        LogConfig.logInfo('📝 Nom complet suggéré: ${suggestedFullName.trim()}');
      } else {
        LogConfig.logInfo('Aucun nom complet suggéré disponible');
      }
      
      // Générer une suggestion de nom d'utilisateur via le BLoC
      try {
        final suggestedUsername = await authBloc.getUsernameSuggestion();
        if (suggestedUsername.isNotEmpty) {
          // CORRECTION : Ajouter le @ automatiquement lors de la suggestion
          final usernameWithAt = suggestedUsername.startsWith('@') 
              ? suggestedUsername 
              : '@$suggestedUsername';
          _usernameController.text = usernameWithAt;
          LogConfig.logInfo('📝 Username suggéré: $usernameWithAt');
        }
      } catch (e) {
        LogConfig.logInfo('Impossible de suggérer un nom d\'utilisateur: $e');
        // Fallback local
        final email = socialInfo['email'];
        if (email != null) {
          final fallbackUsername = '@${email.split('@').first.toLowerCase()}';
          _usernameController.text = fallbackUsername;
          LogConfig.logInfo('📝 Username fallback: $fallbackUsername');
        }
      }
    } catch (e) {
      LogConfig.logInfo('Erreur lors du chargement des suggestions: $e');
      // En cas d'erreur, on continue sans suggestions
    } finally {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _avatar = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.imagePickError(e.toString()),
          ),
        );
      }
    }
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.fullNameRequired;
    }
    if (value.trim().length < 2) {
      return context.l10n.fullNameMinLength;
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.usernameRequired;
    }
    
    // Supprimer le @ au début si présent pour la validation
    final username = value.startsWith('@') ? value.substring(1) : value;
    
    if (username.length < 3) {
      return context.l10n.usernameMinLength;
    }
    
    // Vérifier que le nom d'utilisateur ne contient que des caractères valides
    final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      return context.l10n.usernameInvalidChars;
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Authenticated) {
          // Profil complété avec succès, aller à l'accueil
          context.go('/home');
        } else if (authState is AuthError) {
          // Afficher l'erreur avec plus de contexte
          String errorMessage = authState.message;
          
          // Si c'est une erreur d'avatar, être plus informatif
          if (errorMessage.contains('upload') || errorMessage.contains('avatar')) {
            errorMessage = context.l10n.avatarUploadWarning;
            
            // Même si l'avatar a échoué, on peut considérer que le profil est créé et rediriger vers l'accueil après un délai
            Future.delayed(Duration(seconds: 2), () {
              if (context.mounted) {
                context.go('/home');
              }
            });
          }

          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isError: true,
              title: errorMessage,
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final isLoading = authState is AuthLoading;

          return Stack(
            children: [
              Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: Text(
                    context.l10n.setupAccountTitle,
                    style: context.bodySmall?.copyWith(
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: isLoading ? null : _pickAvatar,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: context.adaptiveBorder,
                                      shape: BoxShape.circle,
                                    ),
                                    child: _avatar == null 
                                    ? Icon(
                                      HugeIcons.solidRoundedCenterFocus,
                                      color: context.adaptiveDisabled,
                                      size: 80,
                                    ) 
                                    : ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
                                      child: Image.file(
                                        _avatar!, 
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: EdgeInsets.all(10.0),
                                      decoration: BoxDecoration(
                                        color: context.adaptivePrimary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.adaptiveBackground,
                                          width: 3,
                                        ),
                                      ),
                                      child: Icon(HugeIcons.solidRoundedCamera01),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            40.h,
                            Text(
                              context.l10n.onboardingInstruction,
                              style: context.bodySmall?.copyWith(
                                color: context.adaptiveTextPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.start,
                            ),
                            20.h,
                            // Formulaire
                            AuthTextField(
                              hint: context.l10n.fullNameHint,
                              textCapitalization: TextCapitalization.words,
                              controller: _fullNameController,
                              validator: _validateFullName,
                              enabled: !isLoading && !_isLoadingSuggestions,
                            ),
                            15.h,
                            AuthTextField(
                              hint: context.l10n.usernameHint,
                              controller: _usernameController,
                              validator: _validateUsername,
                              enabled: !isLoading && !_isLoadingSuggestions,
                              onChanged: (value) {
                                // CORRECTION : Gestion plus robuste du @
                                if (value.isNotEmpty) {
                                  // Si l'utilisateur commence à taper sans @, l'ajouter
                                  if (!value.startsWith('@')) {
                                    final newValue = '@$value';
                                    _usernameController.value = TextEditingValue(
                                      text: newValue,
                                      selection: TextSelection.collapsed(offset: newValue.length),
                                    );
                                  }
                                }
                                // Si l'utilisateur efface tout, remettre juste @
                                else {
                                  _usernameController.value = TextEditingValue(
                                    text: '@',
                                    selection: TextSelection.collapsed(offset: 1),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
              
                        // Bouton en bas
                        Positioned(
                          left: 15,
                          right: 15,
                          bottom: 40,
                          child: _buildCompleteButton(isLoading),
                        ),                
                      ],
                    ),
                  ),
                ),
              ),
              
              // Overlay de chargement
              if (isLoading)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  color: context.adaptiveBackground.withValues(alpha: 0.8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(context.adaptivePrimary),
                        ),
                        20.h,
                        Text(
                          context.l10n.creatingProfile,
                          style: context.bodyMedium?.copyWith(
                            color: context.adaptiveTextPrimary,
                            fontSize: 17
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildCompleteButton(bool isLoading) {
    return SquircleContainer(
      onTap: (isLoading || _isLoadingSuggestions) ? null : _handleCompleteProfile,
      height: 60,
      color: (isLoading || _isLoadingSuggestions) ? context.adaptivePrimary.withValues(alpha: 0.5) : context.adaptivePrimary,
      radius: 30,
      padding: EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 5.0,
      ),
      child: Center(
        child: (isLoading || _isLoadingSuggestions)
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          )
        : Text(
            context.l10n.complete,
            style: context.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
      ),
    );
  }

  void _handleCompleteProfile() {
    if (_formKey.currentState!.validate()) {
      // Nettoyer le nom d'utilisateur (supprimer @ au début)
      String username = _usernameController.text.trim();
      if (username.startsWith('@')) {
        username = username.substring(1);
      }

      LogConfig.logInfo('📝 Envoi complétion profil: ${_fullNameController.text.trim()} / $username');

      context.authBloc.add(
        CompleteProfileRequested(
          fullName: _fullNameController.text.trim(),
          username: username,
          avatar: _avatar,
        ),
      );
    }
  }
}