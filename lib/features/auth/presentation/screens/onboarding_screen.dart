// lib/features/auth/presentation/screens/onboarding_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

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

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _avatar = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom complet est requis';
    }
    if (value.trim().length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom d\'utilisateur est requis';
    }
    
    // Supprimer le @ au début si présent
    final username = value.startsWith('@') ? value.substring(1) : value;
    
    if (username.length < 3) {
      return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
    }
    
    // Vérifier que le nom d'utilisateur ne contient que des caractères valides
    final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      return 'Seules les lettres, chiffres et _ sont autorisés';
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
            errorMessage = 'Profil créé mais l\'avatar n\'a pas pu être uploadé. Vous pourrez l\'ajouter plus tard.';
            
            // Même si l'avatar a échoué, on peut considérer que le profil est créé
            // et rediriger vers l'accueil après un délai
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) context.go('/home');
            });
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: errorMessage.contains('avatar') ? Colors.orange : Colors.red,
              duration: Duration(seconds: errorMessage.contains('avatar') ? 6 : 4),
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final isLoading = authState is AuthLoading;

          return Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                "Set up your account",
                style: context.bodySmall?.copyWith(
                  color: Colors.white,
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
                                  color: Colors.white12,
                                  shape: BoxShape.circle,
                                ),
                                child: _avatar == null 
                                ? Icon(
                                  HugeIcons.solidRoundedCenterFocus,
                                  color: Colors.white38,
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
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(HugeIcons.solidRoundedCamera01),
                                ),
                              ),
                            ],
                          ),
                        ),
                        40.h,
                        Text(
                          "Please complete all the information presented below to create your account.",
                          style: context.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        20.h,
                        // Formulaire
                        AuthTextField(
                          hint: "John Doe",
                          textCapitalization: TextCapitalization.words,
                          controller: _fullNameController,
                          validator: _validateFullName,
                          enabled: !isLoading,
                        ),
                        15.h,
                        AuthTextField(
                          hint: "@johndoe",
                          controller: _usernameController,
                          validator: _validateUsername,
                          enabled: !isLoading,
                          onChanged: (value) {
                            // Ajouter automatiquement @ au début si pas présent
                            if (value.isNotEmpty && !value.startsWith('@')) {
                              _usernameController.value = TextEditingValue(
                                text: '@$value',
                                selection: TextSelection.collapsed(offset: value.length + 1),
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

                    // Overlay de chargement
                    if (isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                            20.h,
                            Text(
                              'Création de votre profil...',
                              style: context.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildCompleteButton(bool isLoading) {
    return SquircleContainer(
      onTap: isLoading ? null : _handleCompleteProfile,
      height: 60,
      color: isLoading ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primary,
      radius: 30,
      padding: EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 5.0,
      ),
      child: Center(
        child: isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          )
        : Text(
            "Complete",
            style: context.bodySmall?.copyWith(
              color: Colors.black,
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

      context.read<AuthBloc>().add(
        CompleteProfileRequested(
          fullName: _fullNameController.text.trim(),
          username: username,
          avatar: _avatar,
        ),
      );
    }
  }
}