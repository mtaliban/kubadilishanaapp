/// Ugeuzaji salama wa data za API kuwa Map/List zilizoandaliwa vizuri.
///
/// Huenda backend/Dio ikarudisha `Map<dynamic, dynamic>` (kwa mfano ujumbe
/// uliopitiwa sehemu nyingine) — `as Map<String, dynamic>` moja kwa moja
/// inaanguka na:
///   "type '_Map<dynamic, dynamic>' is not a subtype of type
///    'Map<String, dynamic>' in type cast"
/// Helpers hizi huwa na kugeuza kwa undani (nested maps na lists zote).
library;

/// Geuza value yoyote iwe Map<String, dynamic> salama (deep).
Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, val) {
      if (val is Map) return MapEntry(val.toString(), asMap(val));
      if (val is List) return MapEntry(val.toString(), asList(val));
      return MapEntry(val.toString(), val);
    });
  }
  return <String, dynamic>{};
}

/// Kama asMap ila inarudisha null value ikiwa null (kwa `as Map<...>?`).
Map<String, dynamic>? asMapOrNull(dynamic v) {
  if (v == null) return null;
  return asMap(v);
}

/// Geuza List yoyote iwe List<dynamic> yenye maps salama ndani (deep).
List<dynamic> asList(dynamic v) {
  if (v is List) {
    return v.map((e) {
      if (e is Map) return asMap(e);
      if (e is List) return asList(e);
      return e;
    }).toList();
  }
  return <dynamic>[];
}
