--------------------------------------------------------------------------------
-- Auto-Login ("Remember Me" for 1 Year) - Prerequisites
-- Run once before adding the procedures to the ADMI_AUTHENTICATION package.
--------------------------------------------------------------------------------

-- 1. Auto-login columns on SUPER_ADMIN
--    (skip any column that already exists; SUAD_COOKIE must hold 64 chars,
--     SUAD_AUTO_LOGIN_YN must hold 'REMEMBER' = 8 chars)
ALTER TABLE super_admin ADD (
    suad_auto_login_yn      VARCHAR2(10),
    suad_cookie             VARCHAR2(100),
    suad_cookie_expire_date DATE
);

-- 2. Index for a fast token lookup on every login page load
CREATE INDEX super_admin_cookie_idx ON super_admin (suad_cookie);

-- 3. Secure random token generation (Pr_Login_User uses DBMS_CRYPTO).
--    Run as SYS / ADMIN and replace YOUR_SCHEMA with your APEX parsing schema.
--    The grant must be direct (not through a role) for use inside a package.
-- GRANT EXECUTE ON SYS.DBMS_CRYPTO TO YOUR_SCHEMA;
