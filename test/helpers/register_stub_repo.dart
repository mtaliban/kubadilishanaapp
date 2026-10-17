// ============================================================================
// test/helpers/register_stub_repo.dart
// Repo bandia ya kawaida kwa tests za usajili — API ya papo-hapo (hakuna
// mtandao ndani ya tests). RegOption zote zina id halisi.
// ============================================================================
import 'package:kubadilishanaapp/screens/register_screen.dart';

final RegistrationRepository stubRegistrationRepository = _StubRepo();

class _StubRepo implements RegistrationRepository {
  @override
  Future<bool> isPhoneAvailable(String phone) async => true;
  @override
  Future<List<RegOption>> regions() async => [RegOption(id: '1', label: 'Mkoa')];
  @override
  Future<List<RegOption>> districts(RegOption region) async =>
      [RegOption(id: '11', label: 'Wilaya')];
  @override
  Future<List<RegOption>> schools(RegOption district) async =>
      [RegOption(id: '111', label: 'Shule')];
  @override
  Future<List<RegOption>> facilities(RegOption district) async =>
      [RegOption(id: '111', label: 'Kituo')];
  @override
  Future<List<RegOption>> referralHospitals(RegOption region) async =>
      [RegOption(id: '9', label: 'Hospitali')];
  @override
  Future<List<RegOption>> cadres() async =>
      [RegOption(id: 'DOC', label: 'Daktari')];
  @override
  Future<List<RegOption>> subjects(EduLevel level) async =>
      [RegOption(id: 'M1', label: 'Hisabati')];
  @override
  Future<void> submit(RegistrationData data) async {}
}
