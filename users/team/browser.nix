_:
let
  dj_url = "https://judge.gehack.nl";
  devdocs_url = "https://devdocs.io/";
in
{
  programs.firefox = {
    enable = true;
    policies = {
      Homepage = {
        URL = dj_url;
        Locked = false;
        StartPage = "homepage";
      };
      DisplayBookmarksToolbar = "always";
      Bookmarks = [
        {
          Title = "DOMjudge";
          URL = dj_url;
          Placement = "toolbar";
        }
        {
          Title = "DevDocs";
          URL = devdocs_url;
          Placement = "toolbar";
        }
      ];
    };
  };
}

