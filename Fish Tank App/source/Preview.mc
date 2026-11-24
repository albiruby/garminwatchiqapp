// Screenshot mode. tools/capture.ps1 rewrites these values while it runs and always
// switches ON back to false. With ON = true the app skips the save file and shows a
// populated demo tank in the chosen style/theme.
module Preview {
    const ON = false;
    const STYLE = 0;   // 0 Modern Pixel, 1 Minimalist, 2 Pseudo-3D
    const THEME = 3;   // 0 Tropical, 1 Freshwater, 2 Fantasy, 3 Mixed, 4 Frozen, 5 Deep
    const MODE = 0;    // 0 play, 1 style picker, 2 theme picker, 3 gift card, 4 run card, 5 build
    const SCREEN = 0;  // 0 tank, else a screen opened on top (PreviewScreens.open)
}
