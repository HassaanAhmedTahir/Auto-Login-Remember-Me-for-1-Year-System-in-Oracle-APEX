--------------------------------------------------------------------------------
-- Procedure : pr_autologin
-- Trigger   : Before Header process on page 9999 (login page), Sequence 20
--             (must run AFTER the pr_logout process)
-- Purpose   : Checks for a valid "remember me" cookie on the login page and,
--             if found, logs the user in automatically and redirects to the
--             home page. If the cookie is unknown or expired, or the account
--             is no longer active, the stale cookie (and its DB token) is
--             cleared and the normal login page renders.
--------------------------------------------------------------------------------
PROCEDURE pr_autologin
IS
    c_cookie_name   CONSTANT VARCHAR2(30) := 'WESS_CAMPUS';

    l_cookie_rec             OWA_COOKIE.cookie;
    v_browser_cookie         VARCHAR2(4000);

    v_suad_id                NUMBER;
    v_suad_email             VARCHAR2(4000);
    v_suad_active_yn         VARCHAR2(4);
    v_suad_deleted_yn        VARCHAR2(4);

    ------------------------------------------------------------
    -- 🔹 Local helper: expire the cookie in the browser
    ------------------------------------------------------------
    PROCEDURE expire_browser_cookie
    IS
    BEGIN
        htp.p(
            'Set-Cookie: ' || c_cookie_name || '=; Path=/; Max-Age=0; '
            || 'Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Lax'
        );
    END expire_browser_cookie;

BEGIN
    ------------------------------------------------------------
    -- 🔹 Try to read cookie from browser
    ------------------------------------------------------------
    l_cookie_rec := OWA_COOKIE.get(c_cookie_name);

    IF l_cookie_rec.num_vals > 0 THEN
        v_browser_cookie := l_cookie_rec.vals(1);
    END IF;

    -- no cookie -> nothing to do, normal login page renders
    IF v_browser_cookie IS NULL THEN
        RETURN;
    END IF;

    ------------------------------------------------------------
    -- 🔹 Look up a valid (non-expired) Auto-Login token
    ------------------------------------------------------------
    BEGIN
        SELECT S.SUAD_ID
             , S.SUAD_EMAIL
             , S.SUAD_ACTIVE_YN
             , S.SUAD_DELETED_YN
          INTO v_suad_id
             , v_suad_email
             , v_suad_active_yn
             , v_suad_deleted_yn
          FROM SUPER_ADMIN S
         WHERE S.SUAD_AUTO_LOGIN_YN      = 'REMEMBER'
           AND S.SUAD_COOKIE             = v_browser_cookie
           AND S.SUAD_COOKIE_EXPIRE_DATE >= SYSDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
            -- unknown, expired or revoked token -> remove the stale cookie
            expire_browser_cookie;
            RETURN;
    END;

    ------------------------------------------------------------
    -- 🔹 Validate account status
    ------------------------------------------------------------
    IF v_suad_active_yn = 'YES'
    AND v_suad_deleted_yn = 'NO' THEN

        --------------------------------------------------------
        -- 🔹 Perform Auto-Login and redirect to Home Page
        --------------------------------------------------------
        wwv_flow_custom_auth_std.post_login(
              p_uname      => v_suad_email
            , p_password   => NULL
            , p_session_id => V('APP_SESSION')
            , p_flow_page  => V('APP_ID') || ':1'
        );

    ELSE
        --------------------------------------------------------
        -- 🔹 Account deactivated or deleted -> revoke the token
        --    in the DB and remove the cookie from the browser
        --------------------------------------------------------
        UPDATE SUPER_ADMIN
           SET SUAD_AUTO_LOGIN_YN      = 'NO'
             , SUAD_COOKIE             = NULL
             , SUAD_COOKIE_EXPIRE_DATE = NULL
             , SUAD_UPDATED            = SYSDATE
         WHERE SUAD_ID = v_suad_id;

        COMMIT;

        expire_browser_cookie;
    END IF;

EXCEPTION
    -- let APEX finish the redirect started by post_login
    WHEN apex_application.e_stop_apex_engine THEN
        RAISE;
    -- avoid breaking the login page on any other cookie problem
    WHEN OTHERS THEN
        NULL;
END pr_autologin;
