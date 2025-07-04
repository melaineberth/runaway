import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
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
            title: context.l10n.selectionError(e.toString()),
            icon: HugeIcons.solidRoundedAlert02,
            color: Colors.red,
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
        onValid: () => _pickAvatar(ImageSource.camera),
        onCancel: () => _pickAvatar(ImageSource.gallery),
      )
    );
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
        12.h,
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
        12.h,
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
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated && _isLoading) {
          // Profil mis à jour avec succès
          setState(() {
            _isLoading = false;
          });
          
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: context.l10n.profileUpdated,
              icon: HugeIcons.strokeRoundedCheckmarkCircle03,
              color: Colors.green,
            ),
          );
          
          context.pop();
        } else if (state is AuthError && _isLoading) {
          // Erreur lors de la mise à jour
          setState(() {
            _isLoading = false;
          });
          
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: context.l10n.profileUpdateError,
              icon: HugeIcons.solidRoundedAlert02,
              color: Colors.red,
            ),
          );
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              forceMaterialTransparency: true,
              backgroundColor: Colors.transparent,
              title: Text(
                context.l10n.editProfile,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveTextPrimary,
                ),
              ),
              leading: IconButton(
                onPressed: _isLoading ? null : context.pop,
                icon: Icon(
                  HugeIcons.strokeSharpArrowLeft02,
                  color: _isLoading ? context.adaptiveDisabled : context.adaptiveTextPrimary,
                ),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FadeTransition(
                    opacity: _fadeController,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [                      
                          // Section Avatar
                          _buildAvatarSection(),
                          
                          50.h,
                          
                          // Section Nom complet
                          _buildFullNameField(),
                          
                          30.h,
                          
                          // Section Username (désactivé)
                          _buildUsernameField(),
                          
                          40.h,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bouton en bas
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: _buildCompleteButton(_isLoading),
          ),                
        ],
      ),
    );
  }

  Widget _buildCompleteButton(bool isLoading) {
    return SquircleContainer(
      onTap: _hasChanges ? _saveProfile : null,
      height: 60,
      color: isLoading || !_hasChanges ? context.adaptivePrimary.withValues(alpha: 0.6) : context.adaptivePrimary,
      radius: 30,
      padding: EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 5.0,
      ),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: Center(
          child: isLoading
          ? Text(
              "Modification en cours...",
              style: context.bodySmall?.copyWith(
                fontSize: 19,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
            .animate(onPlay: (controller) => controller.loop())
            .shimmer(color: context.adaptivePrimary, duration: Duration(seconds: 2))
          : Text(
              context.l10n.complete,
              style: context.bodySmall?.copyWith(
                fontSize: 19,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
        ),
      ),
    );
  }
}