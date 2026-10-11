// register_flow_entry.dart
// Adapter MCONGE ya /register — inaunganisha RegistrationFlowPage (screen mpya
// halisi, mockup code) na API halisi kupitia RealRegistrationRepository:
//   - repo (register_repo.dart): checkPhone, regions, districts, shule/vituo,
//     hospitali za rufaa, kada, masomo, na submit → /auth/register
//   - onFinished: token imetoka — AuthProvider ina-save + ku-enter dashboard
//     (AuthProvider.register inafanya hivyo ndani ya repo.submit).

import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'register_repo.dart' show RealRegistrationRepository;

class RegisterFlowEntry extends StatelessWidget {
  const RegisterFlowEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return RegistrationFlowPage(
      repository: RealRegistrationRepository(),
      onLoginTap: () => Navigator.pushReplacementNamed(context, '/login'),
      onFinished: (data) {
        // AuthProvider.register (ndani ya repo.submit) tayari ame-save token
        // na ku-set user. Nenda dashboard mara moja.
        Navigator.pushReplacementNamed(context, '/dashboard');
      },
    );
  }
}
