// register_repo.dart
// RealRegistrationRepository — inaunganisha RegistrationFlowPage (register_screen.dart)
// na API halisi ya backend:
//   isPhoneAvailable  → GET /auth/check-phone/:phone
//   regions           → GET /locations/regions
//   districts         → GET /locations/regions/:id/districts
//   facilities/schools→ GET /locations/districts/:id/facilities (category health/education)
//   referralHospitals → GET /locations/regions/:id/facilities?employment_sector=wizara_afya
//   cadres            → GET /cadres (category = idara halisi)
//   subjects          → GET /cadres/subjects (level Primary/Secondary)
//   submit            → POST /auth/register (payload ile ile ya adapter ya zamani)
//
// Kila RegOption ina id halisi ya API ndani yake (id='12', id='227' nk.) —
// submit inajenga payload ya RegisterRequest kutoka ids hizo moja kwa moja.

import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart' show RegistrationRepository, RegistrationData,
    RegOption, EduLevel, RegTargetData, RegisterException;

class RealRegistrationRepository implements RegistrationRepository {
  final ApiService _api = ApiService();

  // ── Category code (idara) kutoka jina la idara halisi (backend codes) ──
  static const _deptNameToCode = {
    'Afya': 'health',
    'Elimu': 'education',
    'Kilimo na ufugaji': 'agriculture',
    'Watumishi wa Umma': 'public_service',
  };

  // Cache ndogo ya category code ya idara iliyochaguliwa (submit inaitumia).
  String get _kind => _deptNameToCode[dataCached._idara] ?? 'health';

  late final _DataCache dataCached = _DataCache();

  // ── Helpers ya kusoma majibu ──
  static List<Map<String, dynamic>> _list(dynamic d) {
    final l = d is List ? d : ((d as Map?)?['results'] ?? d?['items'] ?? []) as List?;
    return (l ?? []).cast<Map<String, dynamic>>().whereType<Map<String, dynamic>>().toList();
  }

  static String _idOf(Map<String, dynamic> m) =>
      '${m['id'] ?? m['_id'] ?? m['code'] ?? ''}'.trim();

  static String _nameOf(Map<String, dynamic> m) =>
      '${m['name'] ?? m['label'] ?? m['full_name'] ?? m['code'] ?? ''}'.trim();

  @override
  Future<bool> isPhoneAvailable(String phone) async {
    try {
      final res = await _api.checkPhone(phone);
      final d = res.data as Map? ?? {};
      // Backend: {'available': true/false} ama {'exists': false}
      final avail = d['available'] ?? !(d['exists'] ?? false);
      return avail == true;
    } catch (_) {
      return true; // network hitilafu isiizuie mtumiaji (kama skrini zamani)
    }
  }

  @override
  Future<List<RegOption>> regions() async {
    final res = await _api.getRegions();
    return [
      for (final m in _list(res.data))
        if (_nameOf(m).isNotEmpty)
          RegOption(id: _idOf(m), label: _nameOf(m)),
    ];
  }

  @override
  Future<List<RegOption>> districts(RegOption region) async {
    final rid = int.tryParse(region.id);
    if (rid == null) return const [];
    final res = await _api.getDistricts(rid);
    return [
      for (final m in _list(res.data))
        if (_nameOf(m).isNotEmpty)
          RegOption(id: _idOf(m), label: _nameOf(m)),
    ];
  }

  @override
  Future<List<RegOption>> schools(RegOption district) async {
    final did = int.tryParse(district.id);
    if (did == null) return const [];
    final res = await _api.getFacilities(did, category: 'education');
    final opts = <RegOption>[];
    for (final m in _list(res.data)) {
      final name = _nameOf(m);
      if (name.isEmpty) continue;
      opts.add(RegOption(id: _idOf(m), label: name, subtitle: '${m['ward'] ?? ''}'.trim().isEmpty ? null : '${m['ward']}'));
    }
    return opts;
  }

  @override
  Future<List<RegOption>> facilities(RegOption district) async {
    final did = int.tryParse(district.id);
    if (did == null) return const [];
    final res = await _api.getFacilities(did, category: 'health');
    final opts = <RegOption>[];
    for (final m in _list(res.data)) {
      final name = _nameOf(m);
      if (name.isEmpty) continue;
      opts.add(RegOption(id: _idOf(m), label: name, subtitle: '${m['ward'] ?? ''}'.trim().isEmpty ? null : '${m['ward']}'));
    }
    return opts;
  }

  @override
  Future<List<RegOption>> referralHospitals(RegOption region) async {
    final rid = int.tryParse(region.id);
    if (rid == null) return const [];
    final res = await _api.getFacilitiesByRegion(rid,
        category: 'health', employmentSector: 'wizara_afya');
    final opts = <RegOption>[];
    for (final m in _list(res.data)) {
      final name = _nameOf(m);
      if (name.isEmpty) continue;
      opts.add(RegOption(id: _idOf(m), label: name));
    }
    return opts;
  }

  @override
  Future<List<RegOption>> cadres() async {
    final res = await _api.getCadres(category: dataCached.idaraCode);
    final opts = <RegOption>[];
    for (final m in _list(res.data)) {
      final name = _nameOf(m);
      if (name.isEmpty) continue;
      // Subtitle = display name ya kada (backend: display_name)
      opts.add(RegOption(id: '${m['code'] ?? _idOf(m)}', label: name,
          subtitle: '${m['display_name'] ?? ''}'.trim().isEmpty
              ? null
              : '${m['display_name']}'));
    }
    return opts;
  }

  @override
  Future<List<RegOption>> subjects(EduLevel level) async {
    final res = await _api.getSubjects(
        level: level == EduLevel.sekondari ? 'Secondary' : 'Primary');
    return [
      for (final m in _list(res.data))
        if (_nameOf(m).isNotEmpty)
          RegOption(id: '${m['code'] ?? _idOf(m)}', label: _nameOf(m)),
    ];
  }

  // ── SUBMIT: payload halisi ya RegisterRequest (kama adapter ya zamani) ──
  @override
  Future<void> submit(RegistrationData data) async {
    dataCached._idara = data.idara; // kada/subjects hyppt category sahihi

    final isAfya = data.idara == 'Afya';
    final isWA = isAfya && data.wizara == 'Wizara ya Afya';
    final category = _deptNameToCode[data.idara] ?? 'health';
    final employmentSector = isAfya
        ? (isWA ? 'wizara_afya' : 'tamisemi')
        : (data.idara.startsWith('Watumishi') ? 'raisi_utumishi' : null);

    // Eneo la sasa (StationInput)
    final station = <String, dynamic>{
      'region_id': int.tryParse(data.region.id),
      'region_name': data.region.label,
      if (!isWA && data.district != null) ...{
        'district_id': int.tryParse(data.district!.id),
        'district_name': data.district!.label,
      },
      // Wizara ya Afya: hospitali ya rufaa ya sasa
      if (isWA && data.hospital != null) ...{
        'district_id': null,
        'district_name': null,
        'facility_id': int.tryParse(data.hospital!.id) ?? data.hospital!.id,
        'facility_name': data.hospital!.label,
        'facility_type': 'hospital',
      },
      // TAMISEMI/Elimu: shule ama kituo cha sasa
      if (!isWA && isAfya && data.facility != null) ...{
        'facility_id': int.tryParse(data.facility!.id) ?? data.facility!.id,
        'facility_name': data.facility!.label,
        'facility_type': 'facility',
      },
      if (!isAfya && data.school != null) ...{
        'facility_id': int.tryParse(data.school!.id) ?? data.school!.id,
        'facility_name': data.school!.label,
        'facility_type': 'school',
      },
    };

    // Maeneo ya lengo (DestinationInput) — sahihi kama adapter ya zamani
    final destinations = <Map<String, dynamic>>[];
    if (isWA) {
      // Single target: mkoa + hospitali ya rufaa ya lengo (au bila hospitali)
      final t0 = data.targets.isNotEmpty ? data.targets.first : null;
      if (t0 != null) {
        destinations.add({
          'region_id': int.tryParse(t0.region.id) ?? t0.region.id,
          'region_name': t0.region.label,
          'district_id': null,
          'district_name': null,
          'facility_id': data.targetHospital == null
              ? null
              : (int.tryParse(data.targetHospital!.id) ?? data.targetHospital!.id),
          'facility_name': data.targetHospital?.label,
          'notes': null,
        });
      }
    } else {
      for (final t in data.targets) {
        if (t.anyDistrict || t.districts.isEmpty) {
          // "Wilaya yeyote" — mkoa tu
          destinations.add({
            'region_id': int.tryParse(t.region.id) ?? t.region.id,
            'region_name': t.region.label,
            'district_id': null,
            'district_name': null,
            'facility_id': t.facility == null
                ? null
                : (int.tryParse(t.facility!.id) ?? t.facility!.id),
            'facility_name': t.facility?.label,
            'notes': null,
          });
        } else {
          // Entry moja kwa kila wilaya iliyochaguliwa
          for (final d in t.districts) {
            destinations.add({
              'region_id': int.tryParse(t.region.id) ?? t.region.id,
              'region_name': t.region.label,
              'district_id': int.tryParse(d.id) ?? d.id,
              'district_name': d.label,
              'facility_id': t.facility == null
                  ? null
                  : (int.tryParse(t.facility!.id) ?? t.facility!.id),
              'facility_name': t.facility?.label,
              'notes': null,
            });
          }
        }
      }
    }

    // Miaka: "Mwaka 1" → 1, "Miaka 2" → 2, "Miaka 3+" → 3
    final years = data.years.startsWith('1') ? 1 : (data.years.startsWith('2') ? 2 : 3);

    final payload = <String, dynamic>{
      'full_name': data.name,
      'phone_primary': data.phone,
      'phone_alt': data.whatsapp,
      'category': category,
      if (employmentSector != null) 'employment_sector': employmentSector,
      'cadre_code': isAfya ? (data.cheo?.id ?? '') : '',
      'subjects':
          isAfya ? const [] : [for (final s in data.subjects) s.id],
      'years_of_service': years,
      'current_station': station,
      'desired_destinations': destinations,
    };

    // DAAIMI ULIZA MATOKEO: hata kama API imeshindwa (409 namba imetumika,
    // 422 kada siyo sahihi, n.k.), submit HAIFAA kutoka na mtumiaji aondoke
    // akiwa "amejisajili" kumbe hakuna akaunti iliyorekodiwa. Ndiyo sababu
    // waliosajiliwa hawakuonekana kwenye orodha ya admin.
    final ok = await AuthProvider().register(payload);
    if (!ok) {
      throw RegisterException(
          AuthProvider().error ?? 'Imeshindikana kujisajili. Jaribu tena.');
    }
  }
}

/// Cache ndogo ya idara kwa ajili ya category ya cadres()/subjects() —
/// RegistrationFlowPage inaita _repo.cadres() bila kumpa idara; hii inaumia
/// kumbukumbu ya idara iliyochaguliwa wakati wa kufika kwenye hatua ya Kada.
class _DataCache {
  String _idara = 'Afya';
  String get idaraCode => {
        'Afya': 'health',
        'Elimu': 'education',
        'Kilimo na ufugaji': 'agriculture',
        'Watumishi wa Umma': 'public_service',
      }[_idara] ?? 'health';
}
