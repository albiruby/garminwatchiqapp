import Toybox.Lang;

// Opens a screen on top of the tank for screenshots (Preview.SCREEN).
module PreviewScreens {
    function open(n) {
        if (n == 1) { Nav.push(new MainScreen()); }
        else if (n == 2) { Nav.push(new ShopFishScreen()); }
        else if (n == 3) { Nav.push(new InventoryScreen()); }
        else if (n == 4) { Nav.push(new FishProfileScreen(Globals.engine.fish[0].id)); }
        else if (n == 5) { Nav.push(new QuestScreen()); }
        else if (n == 6) { Nav.push(new ActivityScreen()); }
        else if (n == 7) { var v = new ExpeditionView(); Nav.pushView(v, new ExpeditionDelegate(v)); }
        else if (n == 8) { Nav.push(new GamesScreen()); }
        else if (n == 9) { Nav.pushGrid(new DexGrid()); }
        else if (n == 10) { Nav.pushGrid(new TrophyGrid()); }
        else if (n == 11) { Nav.push(new LeagueScreen()); }
        else if (n == 12) { Nav.push(new ProfileScreen()); }
        else if (n == 13) { var v = new BubblePopView(); Nav.pushView(v, new MiniGameDelegate(v)); v.start(); }
        else if (n == 14) { var v = new TreasureDiveView(); Nav.pushView(v, new MiniGameDelegate(v)); v.start(); }
        else if (n == 15) { var v = new FishRaceView(Globals.engine.fish[0]); Nav.pushView(v, new MiniGameDelegate(v)); v.start(); }
        else if (n == 16) { Nav.push(new SettingsScreen()); }
        else if (n == 17) { Nav.push(new ShopDecorScreen()); }
        else if (n == 18) { Nav.push(new EventsScreen()); }
        else if (n == 19) { var v = new DatePickerView(DatePick.RACE); Nav.pushView(v, new DatePickerDelegate(v)); }
    }
}
