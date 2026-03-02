{ dj_url, ... } :
let
  judge_url = dj_url;
  devdocs_url = "https://devdocs.io/";
in
{
  programs.firefox = {
    enable = true;
    
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DisableProfileImport = true; 
      ExtensionSettings = {
        "*" = {
          installation_mode = "blocked";
          # Optional: Custom message shown when an install is blocked
          blocked_install_message = "Extension installation has been disabled."; 
        };
      };

      InstallAddonsPermission = {
        Default = false;
      };

      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true; 
        MoreFromMozilla = false; 
        FirefoxLabs = false; 
        Locked = true;
      };

      Homepage = {
        URL = judge_url;
        Locked = false;
        StartPage = "homepage";
      };

      NoDefaultBookmarks = true; 
      DisplayBookmarksToolbar = "always";
      
      Bookmarks = [
        {
          Title = "DOMjudge";
          URL = judge_url;
          Placement = "toolbar";
        }
        {
          Title = "DevDocs";
          URL = devdocs_url;
          Placement = "toolbar";
        }
      ];
    };

    profiles.default = {
      isDefault = true;
      settings = {
        "browser.bookmarks.addedImportButton" = true;
      };
    };
  };
}
