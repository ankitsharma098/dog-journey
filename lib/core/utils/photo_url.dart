/// Guards every `NetworkImage(photoUrl)` call site in the app.
///
/// `photo_url`/`photos[].url` columns should only ever hold a Supabase
/// Storage https URL (see SupabaseStorageService.upload) — but rows
/// written before that upload path existed hold a raw on-device cache
/// path instead (e.g. `/data/user/0/.../scaled_18.webp`, left over
/// from image_picker's Android compression cache). Handing that to
/// `NetworkImage` throws ArgumentError: "No host specified in URI"
/// and crashes the paint pass. Treat anything that isn't a real
/// http(s) URL as "no photo" rather than trusting the stored value.
bool isRemotePhotoUrl(String? url) =>
    url != null && (url.startsWith('http://') || url.startsWith('https://'));
