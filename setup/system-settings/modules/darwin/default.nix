{ config, pkgs, ... }: {
  
  security.pam.services.sudo_local.touchIdAuth =true;

  system.defaults = {
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically =false;
        AppleMeasurementUnits = "Centimeters";
        AppleShowAllExtensions = true;
        AppleTemperatureUnit = "Celsius";
        InitialKeyRepeat = 14;
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSWindowShouldDragOnGesture = true;
        _HIHideMenuBar = true;
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.sound.beep.volume" = 0.00;
      };
      WindowManager = {
        EnableStandardClickToShowDesktop = false;
        StandardHideDesktopIcons = true;
        StandardHideWidgets = true;
      };
      dock = {
        autohide = true;
        launchanim = false;
        orientation = "right";
        persistent-apps = [
            "/System/Applications/Finder.app"
            "/System/Applications/Utilities/Terminal.app"
        ];
        show-recents = false;
        static-only = true;
        tilesize = 52;
      };
      finder = {
        _FXSortFoldersFirst = true;
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        NewWindowTarget = "Home";
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      loginwindow = {
        DisableConsoleAccess = true;
        GuestEnabled = false;
        RestartDisabled = true;
        SHOWFULLNAME = true;
        ShutDownDisabled = true;
        SleepDisabled = true;
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
	TrackpadThreeFingerDrag = true;
      	Dragging = true;
      };
  };

  time = {
    timeZone = "Europe/London";
  };
}
