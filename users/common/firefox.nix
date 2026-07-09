{
  config,
  dj_url,
  ...
}:
{
  # Shared, contest-hardened Firefox for every user on the teammachine.
  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      NoDefaultBookmarks = true;
      DisplayBookmarksToolbar = "always";

      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DisableProfileImport = true;

      ExtensionSettings = {
        "*" = {
          installation_mode = "blocked";
          blocked_install_message = "Extension installation has been disabled.";
        };
      };

      InstallAddonsPermission.Default = false;

      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
        FirefoxLabs = false;
        Locked = true;
      };

      Bookmarks = [
        {
          Title = "DOMjudge";
          URL = dj_url;
          Placement = "toolbar";
        }
        {
          Title = "DevDocs";
          URL = "https://docs.gehack.nl";
          Placement = "toolbar";
        }
      ];

      Homepage = {
        URL = dj_url;
        StartPage = "homepage";
        Locked = true;
      };

      Preferences = {
        "browser.startup.page" = {
          Value = 1;
          Status = "locked";
        };
        "browser.sessionstore.resume_from_crash" = {
          Value = false;
          Status = "locked";
        };
      };
    };

    profiles.default = {
      isDefault = true;
      settings = {
        "browser.bookmarks.addedImportButton" = true;
      };
    };
  };
}
