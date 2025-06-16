import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _avatar;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _avatar = File(picked.path));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Set up your account",
          style: context.bodySmall?.copyWith(
            color: Colors.white,
          ),
        ),
        // leading: IconButton(
        //   onPressed: () {}, 
        //   icon: Icon(HugeIcons.solidStandardArrowLeft02),
        // ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 15.0,
        ),
        child: Form(
          child: Stack(
            children: [
              Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
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
                          : Image.file(
                            _avatar!, 
                            fit: BoxFit.cover,
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
                  AuthTextField(
                    hint: "John doe",
                    controller: _fullNameController,
                  ),
                  15.h,
                  AuthTextField(
                    hint: "@johndoe",
                    controller: _usernameController,
                  ),
                  15.h,
                  AuthTextField(
                    hint: "+00 0 00 00 00",
                    controller: _phoneController,
                  ),
                ],
              ),
              _buildSignUpButton(onTap: () => {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpButton({required Function()? onTap}) {
    return Positioned(
      left: 15,
      right: 15,
      bottom: 40,
      child: SizedBox(
        width: double.infinity,
        child: SquircleContainer(
          onTap: onTap,
          height: 60,
          color: AppColors.primary,
          radius: 30,
          padding: EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 5.0,
          ),
          child: Center(
            child: Text(
              "Completed",
              style: context.bodySmall?.copyWith(
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}