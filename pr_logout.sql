--------------------------------------------------------------------------------
-- Procedure : pr_logout
-- Trigger   : Before Header process on page 9999 (login page), Sequence 10
--             Server-side condition: Item = Value -> P9999_LOGOUT_YN = YES
-- Purpose   : Runs after a manual sign-out. Clears the auto-login token in
--             the DB (found by the browser cookie, so it works even after
--             the APEX session has already ended), expires the cookie in the
--             browser, shows a language-aware "logged out" message and
--             cleans the address bar so a refresh can't re-trigger it.
--------------------------------------------------------------------------------
PROCEDURE pr_logout
IS
    c_cookie_name   CONSTANT VARCHAR2(30) := 'WESS_CAMPUS';

    l_cookie_rec        OWA_COOKIE.cookie;
    v_browser_cookie    VARCHAR2(4000);
    v_logout_message    VARCHAR2(4000);
    v_clean_url         VARCHAR2(4000);
BEGIN

    ------------------------------------------------------------
    -- 🔹 Set the logout message depending on session language
    ------------------------------------------------------------
    IF LOWER(V('SESSION_LANGUAGE')) = 'de' THEN
        v_logout_message := '👋 Sie wurden erfolgreich von <strong style="color:#0b6623;">WESS Campus Admin</strong> abgemeldet.';
    ELSE
        v_logout_message := '👋 You have been logged out of <strong style="color:#0b6623;">WESS Campus Admin</strong> successfully.';
    END IF;

    ------------------------------------------------------------
    -- 🔹 Read the cookie from the browser (if there is one)
    ------------------------------------------------------------
    BEGIN
        l_cookie_rec := OWA_COOKIE.get(c_cookie_name);
        IF l_cookie_rec.num_vals > 0 THEN
            v_browser_cookie := l_cookie_rec.vals(1);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_browser_cookie := NULL;
    END;

    ------------------------------------------------------------
    -- 🔹 Reset Cookie and Auto-Login Fields
    --    Matched by the cookie itself OR by the current user,
    --    so the token is cleared even when APP_USER is 'nobody'
    ------------------------------------------------------------
    UPDATE SUPER_ADMIN
       SET SUAD_AUTO_LOGIN_YN      = 'NO'
         , SUAD_COOKIE             = NULL
         , SUAD_COOKIE_EXPIRE_DATE = NULL
         , SUAD_UPDATED            = SYSDATE
         , SUAD_UPDATED_BY         = COALESCE(
                                         SYS_CONTEXT('apex$session','app_user'),
                                         SYS_CONTEXT('userenv','os_user'),
                                         SYS_CONTEXT('userenv','session_user')
                                     )
     WHERE (v_browser_cookie IS NOT NULL AND SUAD_COOKIE = v_browser_cookie)
        OR LOWER(SUAD_EMAIL) = LOWER(V('APP_USER'));

    ------------------------------------------------------------
    -- 🔹 Expire the cookie in the browser too (not just the DB)
    ------------------------------------------------------------
    htp.p(
        'Set-Cookie: ' || c_cookie_name || '=; Path=/; Max-Age=0; '
        || 'Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Lax'
    );

    ------------------------------------------------------------
    -- 🔹 Reset the trigger item
    ------------------------------------------------------------
    APEX_UTIL.SET_SESSION_STATE('P9999_LOGOUT_YN', 'NO');

    ------------------------------------------------------------
    -- 🔹 Print the message - shows on THIS render, no redirect
    ------------------------------------------------------------
    apex_application.g_print_success_message := v_logout_message;

    COMMIT;

    ------------------------------------------------------------
    -- 🔹 Silently rewrite the address bar to a clean URL
    ------------------------------------------------------------
    v_clean_url := 'f?p=' || V('APP_ID') || ':9999:' || V('APP_SESSION');

    apex_javascript.add_onload_code(
        'if (window.history && window.history.replaceState) { '
        || 'window.history.replaceState(null, "", "' || v_clean_url || '"); }'
    );

END pr_logout;
