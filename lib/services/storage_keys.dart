import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_language.dart';

/// The persisted-storage schema: every key HandySpeak writes, the schema
/// version, and the load-time migration that upgrades old stores (R1
/// architecture review, issue C3 — [S02-issue-C3]; the standing policy is
/// ADR-0005, `docs/adr/0005-storage-schema-versioning-and-data-safety.md`).
///
/// Controllers own *behaviour* over these keys; this module owns the key
/// names, so the whole persisted schema is visible in one file and no
/// controller carries string literals.
///
/// ## Schema history
///
/// * **v1 (implicit, pre-versioning)** — the language-set keys, the settings
///   booleans, and per-language phrase blobs whose entries were
///   `{text, pinned, uses}` with no id. Nothing recorded a version.
/// * **v2 (current, [kSchemaVersion])** — phrase-blob entries became
///   `{id, text, pinned}`: every phrase gained a stable id (M5 — identity
///   was text equality, so two same-text phrases could not be removed or
///   pinned independently) and lost the never-incremented `uses` field (M2,
///   owner decision 2026-11-28: remove until real usage counters exist).
///   No v1 key changed name or shape.
///
/// ## Migration crash-safety (S02)
///
/// Migration steps are pure and idempotent, and `schema_version` is written
/// **only after every step has succeeded** (version-last). A process death
/// mid-migration therefore re-runs the same steps on the next boot and
/// converges instead of leaving a half-migrated store. [runMigrations] runs
/// inside `StorageService.init()` — before any controller's `load()` — so no
/// controller ever observes a pre-migration store.
///
/// ## Atomicity stance (S02 — recorded, option (a))
///
/// `shared_preferences` has no multi-key transaction. The stance of record
/// is **(a)**: keep the multi-key language-set writes (`main_lang` /
/// `second_lang`, written separately by `LanguageController._persistPair`)
/// and rely on the existing Q17 load-time snap-back that repairs a
/// partially-written set. Candidate (b) — folding both slots into a single
/// `language_set` JSON key so the invariant becomes one write — is
/// deliberately NOT implemented; it falls out nearly for free of the first
/// migration that needs to touch the language keys, and should be picked up
/// then.

/// Marker recording which schema version wrote the store. Absent on v1
/// stores and on fresh installs.
const String kSchemaVersionKey = 'schema_version';

/// The current schema version (see the schema history above).
const int kSchemaVersion = 2;

// ---- Language set (LanguageController) ----

const String kActiveLangKey = 'active_lang';
const String kMainLangKey = 'main_lang';
const String kSecondLangKey = 'second_lang';

// ---- Phrases (PhrasesController) ----

/// The per-language phrase blob, e.g. `phrases_en` (v2 JSON list, see
/// `Phrase.toJson`).
String phrasesKey(AppLanguage lang) => 'phrases_${lang.key}';

/// Quarantine slot for a phrase blob that failed to decode: the corrupt raw
/// content is parked here before the list re-seeds, so a support path can
/// recover the parent's content. Self-capping — the slot is *overwritten*
/// per language, never appended to (S02-issue-C3 item 4).
String phrasesCorruptKey(AppLanguage lang) => 'phrases_${lang.key}.corrupt';

// ---- Settings (SettingsController) ----

const String kDarkModeKey = 'dark_mode';
const String kHapticsKey = 'haptics';
const String kBigLettersKey = 'big_letters';
const String kShowPhrasesKey = 'show_phrases';
const String kSpeakLettersKey = 'speak_letters';
const String kSpeakWordsKey = 'speak_words';
const String kSpeakSymbolsKey = 'speak_symbols';
const String kSpeakPhrasesKey = 'speak_phrases';

/// Pure v1→v2 step for one phrase blob: strips the retired `uses` field
/// (M2) and assigns a stable `id` to every entry lacking one (M5).
///
/// * **Idempotent** — entries that already have an id keep it, `uses` is
///   absent after one pass, so re-running on its own output returns the
///   identical string and the caller writes nothing.
/// * **Id scheme** — new ids count upward from the highest id already in
///   the list, so they never collide with surviving entries.
/// * **`null` = not migratable** — [raw] is corrupt (not JSON, not a list,
///   or an entry no v1/v2 `Phrase.fromJson` could decode: non-String text,
///   non-bool pinned, non-int id). The blob is left byte-identical for
///   `PhrasesController`'s quarantine path instead: that path backs it up
///   under [phrasesCorruptKey] and reports `phrases/load_corrupt` — a
///   migration must not destroy evidence it cannot parse.
String? migratePhrasesBlobV1toV2(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! List) return null;

  final entries = <Map<String, dynamic>>[];
  for (final Object? entry in decoded) {
    if (entry is! Map) return null;
    if (entry['text'] is! String) return null;
    if (entry['pinned'] != null && entry['pinned'] is! bool) return null;
    if (entry['id'] != null && entry['id'] is! int) return null;
    entries.add(Map<String, dynamic>.from(entry));
  }

  var nextId = -1;
  for (final entry in entries) {
    final id = entry['id'];
    if (id is int && id > nextId) nextId = id;
  }
  for (final entry in entries) {
    if (entry['id'] == null) entry['id'] = ++nextId; // M5
    entry.remove('uses'); // M2
  }
  return jsonEncode(entries);
}

/// Runs every pending migration step on [prefs] — called from
/// `StorageService.init()` (version-last): the `schema_version` marker is
/// written only after all steps succeeded, so an interrupted migration
/// (process death, failed write — the error propagates to
/// `StorageService.init()`'s caller) re-runs cleanly on the next boot.
///
/// * Store already at [kSchemaVersion] → no-op.
/// * Store from a *newer* build → left completely untouched (a downgrade
///   must not clobber the newer marker or "migrate" data it does not know).
/// * Corrupt phrase blobs are skipped, not failed — see
///   [migratePhrasesBlobV1toV2].
Future<void> runMigrations(SharedPreferences prefs) async {
  final stored = prefs.getInt(kSchemaVersionKey);
  if (stored == kSchemaVersion) return;
  if (stored != null && stored > kSchemaVersion) return;

  for (final lang in AppLanguage.values) {
    final key = phrasesKey(lang);
    final raw = prefs.getString(key);
    if (raw == null) continue;
    final migrated = migratePhrasesBlobV1toV2(raw);
    if (migrated != null && migrated != raw) {
      await prefs.setString(key, migrated);
    }
  }

  // Version-last — the only write that records the migration as done.
  await prefs.setInt(kSchemaVersionKey, kSchemaVersion);
}
