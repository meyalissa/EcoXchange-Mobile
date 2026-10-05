// EcoXchange Mobile — local Flutter-web Google Maps configuration.
//
// Copy this file to maps_config.js (same folder) and fill in a real Google
// Maps JavaScript API key for local web development/testing. maps_config.js
// itself is gitignored — never commit a real key there. This mirrors the
// existing .env / .env.example convention used elsewhere in this project.
//
// A Maps JavaScript API key is inherently client-visible in any web app
// (there is no way to keep it secret once it's loaded in a browser) — it's
// protected by HTTP-referrer restriction in Google Cloud Console, not by
// secrecy. Restrict it to the exact origins you actually serve from (e.g.
// http://localhost:5000/*) rather than leaving it unrestricted.
window.GOOGLE_MAPS_API_KEY = '';
