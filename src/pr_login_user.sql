--------------------------------------------------------------------------------
-- Procedure : Pr_Login_User
-- Trigger   : Login process on page 9999 (login page)
-- Purpose   : Authenticates the super admin. When pi_auto_login is 'YES' (or
--             'Y') - the "Auto-Login" checkbox is ticked - it stores a new
--             cryptographically random token in SUAD_COOKIE with a 1-year
--             expiry and sets SUAD_AUTO_LOGIN_YN = 'YES', so pr_set_cookie
--             writes the browser cookie on the home page. Otherwise all
--             auto-login fields are cleared.
-- Requires  : EXECUTE on SYS.DBMS_CRYPTO (see prerequisites.sql)
--------------------------------------------------------------------------------
PROCEDURE Pr_Login_User(
      pi_User_Name      IN VARCHAR2
    , pi_Password       IN VARCHAR2
    , pi_App_Id         IN NUMBER
    , pi_app_name       IN VARCHAR2 DEFAULT NULL
    , pi_auto_login     IN VARCHAR2 DEFAULT NULL
) AS

v_Result BOOLEAN := FALSE;
v_cookie VARCHAR2(64);

BEGIN

v_Result := fn_Authenticate_User_super_Admin(
                pi_user_name
              , pi_password
            );

IF v_Result THEN

    ------------------------------------------------------------
    -- 🔹 Auto Login Handling
    ------------------------------------------------------------
    IF UPPER(pi_auto_login) IN ('YES', 'Y') THEN

        -- 64-character, cryptographically secure random token (256 bits)
        v_cookie := RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32));

        UPDATE SUPER_ADMIN
           SET SUAD_AUTO_LOGIN_YN      = 'YES'
             , SUAD_COOKIE             = v_cookie
             , SUAD_COOKIE_EXPIRE_DATE = SYSDATE + 365
             , SUAD_UPDATED            = SYSDATE
             , SUAD_UPDATED_BY         = COALESCE(
                                             SYS_CONTEXT('apex$session','app_user'),
                                             SYS_CONTEXT('userenv','os_user'),
                                             SYS_CONTEXT('userenv','session_user')
                                         )
         WHERE LOWER(SUAD_EMAIL) = LOWER(pi_user_name);

    ELSE

        UPDATE SUPER_ADMIN
           SET SUAD_AUTO_LOGIN_YN      = NULL
             , SUAD_COOKIE             = NULL
             , SUAD_COOKIE_EXPIRE_DATE = NULL
             , SUAD_UPDATED            = SYSDATE
             , SUAD_UPDATED_BY         = COALESCE(
                                             SYS_CONTEXT('apex$session','app_user'),
                                             SYS_CONTEXT('userenv','os_user'),
                                             SYS_CONTEXT('userenv','session_user')
                                         )
         WHERE LOWER(SUAD_EMAIL) = LOWER(pi_user_name);

    END IF;  -- closes pi_auto_login check

    -- Update last login
    UPDATE SUPER_ADMIN
       SET SUAD_LAST_LOGIN = SYSDATE
     WHERE LOWER(SUAD_EMAIL) = LOWER(pi_user_name);

    -- Redirect to application
    WWV_FLOW_CUSTOM_AUTH_STD.POST_LOGIN(
          pi_user_name
        , pi_password
        , V('APP_SESSION')
        , pi_app_id || ':1'
    );

ELSE
    -- Login failed: redirect back to the login page
    -- (built in PL/SQL - &APP_ID. substitutions don't work inside a package)
    APEX_UTIL.REDIRECT_URL(
        'f?p=' || pi_app_id || ':9999:' || V('APP_SESSION')
    );
END IF;  -- closes v_Result check

END Pr_Login_User;
