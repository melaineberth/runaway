import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/config/extensions.dart';
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

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
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

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
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
      context.pop();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    context.read<AuthBloc>().add(
      UpdateProfileRequested(
        fullName: hasNameChange ? fullName : null,
        avatar: _selectedAvatar,
      ),
    );
  }

  Widget _buildAvatarSection() {
    final initialColor = math.Random().nextInt(Colors.primaries.length);
    final avatarSize = 200.0;

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
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
      child: Scaffold(
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
            onPressed: context.pop,
            icon: Icon(
              HugeIcons.strokeSharpArrowLeft02,
              color: context.adaptiveTextPrimary,
            ),
          ),
          actions: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.adaptivePrimary,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                onPressed: _saveProfile,
                icon: Icon(
                  HugeIcons.strokeRoundedTick01,
                  color: context.adaptivePrimary,
                ),
                iconSize: 24,
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(30.0),
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
    );
  }
}