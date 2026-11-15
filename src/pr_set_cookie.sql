--------------------------------------------------------------------------------
-- Procedure : pr_set_cookie
-- Trigger   : Before Header process on page 1 (home page)
-- Purpose   : Runs on the first home page load after a login (once per
--             session, tracked by the application item AI_WELCOME_SHOWN).
--             Looks at the current auto-login state (SUAD_AUTO_LOGIN_YN)
--             and reacts accordingly:
--               'YES'      -> auto-login was just switched on during this
--                             login: write the 1-year cookie to the browser
--                             and flip the DB flag to 'REMEMBER' so future
--                             visits are recognized as cookie-based logins
--               'REMEMBER' -> this login happened automatically via the
--                             remembered cookie (see pr_autologin)
--               anything   -> a normal, one-time login with no auto-login
--               else         enabled
--             In all three cases a language-aware success message is
--             printed, and a confetti celebration with a language-aware
--             overlay fires whenever auto-login is active.
--------------------------------------------------------------------------------
PROCEDURE pr_set_cookie
IS
    c_cookie_name   CONSTANT VARCHAR2(30) := 'WESS_CAMPUS';
    c_shown_item    CONSTANT VARCHAR2(30) := 'AI_WELCOME_SHOWN';

    v_cookie_value           VARCHAR2(4000);   -- current cookie value stored on this user's record
    v_auto_login_yn          VARCHAR2(4000);   -- current auto-login state: 'YES' / 'REMEMBER' / other

    -- msg items (populated per session language below, printed further down)
    v_set_1_year_login       VARCHAR2(4000);   -- shown when auto-login is switched on for the first time
    v_remember_auto_login    VARCHAR2(4000);   -- shown when this login happened automatically via cookie
    v_1_time_login           VARCHAR2(4000);   -- shown on a normal login with no auto-login enabled

    -- confetti overlay texts (only set when auto-login is active)
    v_enabled_title          VARCHAR2(4000);
    v_enabled_text           VARCHAR2(4000);
    v_welcome_title          VARCHAR2(4000);
    v_welcome_text           VARCHAR2(4000);
    v_overlay_title          VARCHAR2(4000);
    v_overlay_text           VARCHAR2(4000);

BEGIN

    ------------------------------------------------------------
    -- 🔹 Only once per login: skip if already shown in this session
    --    (clicking "Home" again won't repeat message + confetti)
    ------------------------------------------------------------
    IF V(c_shown_item) = 'Y' THEN
        RETURN;
    END IF;

    ------------------------------------------------------------
    -- 🔹 Set messages depending on session language
    ------------------------------------------------------------
    IF LOWER(V('SESSION_LANGUAGE')) = 'de' THEN

        v_set_1_year_login    := '✅ Die automatische Anmeldung bei <strong>WESS Campus Admin</strong> wurde für 1 Jahr aktiviert.';
        v_remember_auto_login := '🔐 Sie wurden automatisch bei <strong>WESS Campus Admin</strong> angemeldet.';
        v_1_time_login        := '👋 Sie wurden erfolgreich bei <strong style="color:#0b6623;">WESS Campus Admin</strong> angemeldet.';

        v_enabled_title       := '✅ Automatische Anmeldung aktiviert!';
        v_enabled_text        := 'Sie werden 1 Jahr lang automatisch bei <strong style="color:#0b6623;">WESS Campus Admin</strong> angemeldet.';
        v_welcome_title       := '🔐 Willkommen zurück!';
        v_welcome_text        := 'Sie wurden automatisch bei <strong style="color:#0b6623;">WESS Campus Admin</strong> angemeldet.';

    ELSE

        v_set_1_year_login    := '✅ Automatic login for <strong>WESS Campus Admin</strong> has been enabled for 1 year.';
        v_remember_auto_login := '🔐 You have been logged in to <strong>WESS Campus Admin</strong> automatically.';
        v_1_time_login        := '👋 You have been logged in to <strong style="color:#0b6623;">WESS Campus Admin</strong> successfully.';

        v_enabled_title       := '✅ Auto-Login Enabled!';
        v_enabled_text        := 'You''ll be signed in to <strong style="color:#0b6623;">WESS Campus Admin</strong> automatically for the next year.';
        v_welcome_title       := '🔐 Welcome back!';
        v_welcome_text        := 'You were signed in to <strong style="color:#0b6623;">WESS Campus Admin</strong> automatically.';

    END IF;

    ------------------------------------------------------------
    -- 🔹 Get auto login flag and cookie value for the current user
    ------------------------------------------------------------
    BEGIN
        SELECT SUAD_AUTO_LOGIN_YN
             , SUAD_COOKIE
          INTO v_auto_login_yn
             , v_cookie_value
          FROM super_admin
         WHERE LOWER(suad_email) = LOWER(V('APP_USER'));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;   -- not a super admin record: nothing to do
    END;

    ------------------------------------------------------------
    -- 🔹 React to the auto-login state
    ------------------------------------------------------------

    -- user has just activated auto login (and a token exists)
    IF v_auto_login_yn = 'YES' AND v_cookie_value IS NOT NULL THEN

        -- set the cookie in the browser for 1 year.
        -- Max-Age is the primary expiry; Expires is always written in
        -- English + GMT (whatever the session language is) for older browsers
        htp.p(
            'Set-Cookie: ' || c_cookie_name || '=' || v_cookie_value
            || '; Path=/'
            || '; Max-Age=31536000'
            || '; Expires=' || TO_CHAR(
                                   CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) + 365,
                                   'Dy, DD Mon YYYY HH24:MI:SS',
                                   'NLS_DATE_LANGUAGE=ENGLISH'
                               ) || ' GMT'
            || '; Secure; HttpOnly; SameSite=Lax'
        );

        -- switch auto login type to REMEMBER, so next time it's an auto login via cookie
        UPDATE SUPER_ADMIN
           SET SUAD_AUTO_LOGIN_YN = 'REMEMBER'
         WHERE LOWER(SUAD_EMAIL) = LOWER(V('APP_USER'));

        COMMIT;

        -- success message: user will stay logged in for 1 year
        apex_application.g_print_success_message := v_set_1_year_login;
        v_overlay_title := v_enabled_title;
        v_overlay_text  := v_enabled_text;

    ELSIF v_auto_login_yn = 'REMEMBER' THEN

        -- auto login triggered automatically via cookie
        apex_application.g_print_success_message := v_remember_auto_login;
        v_overlay_title := v_welcome_title;
        v_overlay_text  := v_welcome_text;

    ELSE

        -- user chose no auto login, only a one-time login
        apex_application.g_print_success_message := v_1_time_login;

    END IF;

    ------------------------------------------------------------
    -- 🔹 Remember that the welcome was shown in this session
    --    (if the application item is missing, the page still works)
    ------------------------------------------------------------
    BEGIN
        APEX_UTIL.SET_SESSION_STATE(c_shown_item, 'Y');
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    ------------------------------------------------------------
    -- 🔹 Confetti + overlay whenever auto-login is active
    --    (covers both "just activated" and "auto-logged-in via cookie")
    ------------------------------------------------------------
    IF v_overlay_title IS NOT NULL THEN

        -- inject client-side JS: shows a fading overlay for 7 seconds and
        -- loads the confetti library from CDN for a 7-second confetti burst.
        -- The overlay still shows if the CDN is blocked.
        apex_javascript.add_onload_code(q'~
    (function (title, text) {

        function showOverlay() {
            var style = document.createElement("style");
            style.textContent =
                "@keyframes wessFadeOut { 0% {opacity:1;} 85% {opacity:1;} 100% {opacity:0;} }";
            document.head.appendChild(style);

            var overlay = document.createElement("div");
            overlay.setAttribute("role", "status");
            overlay.style.cssText =
                "position:fixed; top:50%; left:50%; transform:translate(-50%,-50%);" +
                "box-sizing:border-box; max-width:90vw; background:#ffffff; color:#0b6623;" +
                "font-weight:700; font-size:1.6rem; text-align:center;" +
                "padding:45px 90px; border-radius:24px;" +
                "box-shadow:0 10px 30px rgba(0,0,0,0.25);" +
                "z-index:10000; animation:wessFadeOut 6.5s forwards;";
            overlay.innerHTML = title + '<br><span style="font-size:1.2rem;">' + text + '</span>';
            document.body.appendChild(overlay);
            setTimeout(function () { overlay.remove(); }, 7000);
        }

        function startConfetti() {
            if (typeof confetti !== "function") {
                console.warn("Confetti library not loaded.");
                return;
            }

            var duration = 7000;
            var end = Date.now() + duration;
            var defaults = { startVelocity: 35, spread: 360, ticks: 70, zIndex: 9999 };

            function randomInRange(min, max) {
                return Math.random() * (max - min) + min;
            }

            var interval = setInterval(function () {
                var timeLeft = end - Date.now();
                if (timeLeft <= 0) { return clearInterval(interval); }
                var particleCount = 60 * (timeLeft / duration);
                confetti(Object.assign({}, defaults, {
                    particleCount: particleCount,
                    origin: { x: randomInRange(0, 1), y: Math.random() - 0.2 }
                }));
            }, 250);
        }

        showOverlay();

        // dynamically load confetti library from CDN
        var script = document.createElement("script");
        script.src = "https://cdn.jsdelivr.net/npm/canvas-confetti@1.6.0/dist/confetti.browser.min.js";
        script.onload = startConfetti;
        script.onerror = function () {
            console.warn("Confetti library could not be loaded.");
        };
        document.head.appendChild(script);

    })(~'
            || apex_escape.js_literal(v_overlay_title) || ', '
            || apex_escape.js_literal(v_overlay_text)  || ');'
        );

    END IF;

END pr_set_cookie;
