import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  late final TextEditingController _fullNameController;
  late final GlobalKey<FormState> _formKey;
  late final AnimationController _fadeController;
  
  File? _selectedAvatar;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _formKey = GlobalKey<FormState>();

    // Ajouter le listener pour détecter les changements
    _fullNameController.addListener(() {
      setState(() {}); // Rebuild pour mettre à jour l'état du bouton
    });
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedAvatar = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.selectionError(e.toString()),
          ),
        );
      }
    }
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    
    // Vérifier s'il y a des changements
    final hasNameChange = fullName != widget.profile.fullName;
    final hasAvatarChange = _selectedAvatar != null;

    if (!hasNameChange && !hasAvatarChange) {
      if (mounted) {
        context.pop();
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Vider le cache avant la mise à jour si avatar change
    if (hasAvatarChange && widget.profile.hasAvatar) {
      try {
        CachedNetworkImage.evictFromCache(widget.profile.avatarUrl!);
      } catch (e) {
        print('⚠️ Erreur vidage cache: $e');
      }
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.authBloc.add(
          UpdateProfileRequested(
            fullName: hasNameChange ? fullName : null,
            avatar: _selectedAvatar,
          ),
        );
      }
    });
  }

  void chooseTypePicture() {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        title: "Changer de photo", 
        subtitle: "Avant de continuer, veuillez choisir le mode de selection souhaité", 
        validLabel: "Camera",
        cancelLabel: "Gallery",
        onValid: () {
          Navigator.pop(context);
          _pickAvatar(ImageSource.camera);
        },
        onCancel: () {
          Navigator.pop(context);
          _pickAvatar(ImageSource.gallery);
        },
      )
    );
  }

  // 🆕 Ajouter cette méthode pour gérer le succès
  void _handleProfileUpdateSuccess() {
    // Afficher le snackbar de succès
    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        title: 'Profil mis à jour avec succès',
      ),
    );

    // Navigation
    if (mounted) {
      context.pop(); // ou context.pop() selon votre navigation
    }
  }

  Widget _buildAvatarSection() {
    final initialColor = math.Random().nextInt(Colors.primaries.length);
    final avatarSize = 200.0;

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: chooseTypePicture,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _selectedAvatar != null
                    ? Image.file(
                        _selectedAvatar!,
                        fit: BoxFit.cover,
                      )
                    : widget.profile.hasAvatar
                        ? CachedNetworkImage(
                            imageUrl: widget.profile.avatarUrl!,
                            fit: BoxFit.cover,
                            // 🔧 FIX: Ajouter une clé unique pour forcer le rechargement
                            key: ValueKey(widget.profile.avatarUrl),
                            placeholder: (context, url) => Container(
                              color: Colors.primaries[initialColor].withValues(alpha: 0.2),
                              child: Center(
                                child: Text(
                                  widget.profile.initials,
                                  style: context.titleLarge?.copyWith(
                                    color: Colors.primaries[initialColor],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.primaries[initialColor].withValues(alpha: 0.2),
                              child: Center(
                                child: Text(
                                  widget.profile.initials,
                                  style: context.titleLarge?.copyWith(
                                    color: Colors.primaries[initialColor],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.primaries[initialColor].withValues(alpha: 0.2),
                            child: Center(
                              child: Text(
                                widget.profile.initials,
                                style: context.titleLarge?.copyWith(
                                  color: Colors.primaries[initialColor],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
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
              child: Icon(
                HugeIcons.solidRoundedExchange01,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.fullNameTitle, // Vous pouvez ajouter cette traduction
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        8.h,
        AuthTextField(
          hint: context.l10n.fullNameHint,
          textCapitalization: TextCapitalization.words,
          controller: _fullNameController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.l10n.fullNameRequired;
            }
            if (value.trim().length < 2) {
              return context.l10n.fullNameMinLength;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.usernameTitle, // Vous pouvez ajouter cette traduction
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        Text(
          context.l10n.nonEditableUsername, // Remplacer par context.l10n.usernameCannotBeModified
          style: context.bodySmall?.copyWith(
            color: context.adaptiveDisabled,
            fontSize: 14,
            fontWeight: FontWeight.w400
          ),
        ),
        8.h,
        AuthTextField(
          initialValue: widget.profile.username ?? '',
          enabled: false,
          suffixIcon: Icon(
            HugeIcons.strokeRoundedSquareLock02,
            size: 20,
            color: context.adaptiveDisabled,
          ),
        ),
      ],
    );
  }

  bool get _hasChanges {
    final nameChanged = _fullNameController.text.trim() != widget.profile.fullName;
    final avatarChanged = _selectedAvatar != null;
    return nameChanged || avatarChanged;
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [                      
                // Section Avatar
                _buildAvatarSection(),
                
                50.h,
                
                // Section Nom complet
                _buildFullNameField(),
                
                20.h,
                
                // Section Username (désactivé)
                _buildUsernameField(),
                
                40.h,

                _buildCompleteButton(_isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(bool isLoading) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // Écouter spécifiquement les changements de profil
        return previous != current && current is Authenticated;
      },
      listener: (context, state) {
        if (state is Authenticated) {
          // 🆕 Navigation immédiate après succès
          _handleProfileUpdateSuccess();
        }
      },
      child: SquircleBtn(
        isPrimary: true,
        isLoading: isLoading,
        onTap: _hasChanges ? _saveProfile : null,
        label: context.l10n.complete,
      ),
    );
  }
}