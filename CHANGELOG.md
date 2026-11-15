# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-11-15

### Added
- `prerequisites.sql` — auto-login columns, a token index and the `DBMS_CRYPTO` grant.
- `AI_WELCOME_SHOWN` application item so the welcome message and confetti show once per login, not on every Home click.
- Language-aware confetti overlay: "Auto-Login Enabled!" the first time, "Welcome back!" on returning visits (English / German).

### Changed
- The token is now a 64-character, cryptographically secure value from `DBMS_CRYPTO.RANDOMBYTES` (previously `DBMS_RANDOM.STRING`).
- The cookie now also carries `SameSite=Lax` and `Max-Age`.
- The Auto-Login checkbox accepts `YES` or `Y`.
- The overlay still appears when the confetti CDN is blocked.

### Fixed
- The cookie `Expires` date is always written in English and GMT, so German sessions keep a valid 1-year cookie.
- Removed a company check that read the user's deleted flag twice and never checked the company.
- The failed-login redirect used `&APP_ID.` inside a package, where it isn't substituted; it now uses `APEX_UTIL.REDIRECT_URL`.
- Logout clears the token by the browser cookie, so it works after the APEX session has ended.
- The auto-login redirect is no longer swallowed by the `WHEN OTHERS` handler (`e_stop_apex_engine` is re-raised).
- Deactivated accounts have their token revoked; expired or unknown cookies are removed.
- `pr_set_cookie` no longer fails when the user isn't found in `SUPER_ADMIN`.

## [1.0.0]

### Added
- First release, as published in the original blog post.
