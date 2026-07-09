/// Categorizes what kind of site this is.
///
/// - [reader]    : a site where you actively read chapters
/// - [search]    : a site for discovering/tracking novels (e.g. NovelUpdates)
/// - [reference] : a reference site (e.g. Wikipedia)
enum SiteType { reader, search, reference }

/// Converts a [SiteType] to its JSON string representation.
String siteTypeToString(SiteType type) => type.name;

/// Converts a JSON string back to a [SiteType].
/// Falls back to [SiteType.reader] if the string is unrecognised.
SiteType siteTypeFromString(String value) {
  return SiteType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SiteType.reader,
  );
}
