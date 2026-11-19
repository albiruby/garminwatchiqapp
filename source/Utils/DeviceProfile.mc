import Toybox.Graphics;
import Toybox.Lang;

//! Colours and layout helpers (RESTORA palette: deep forest / sage / mint).
module DeviceProfile {
    const COLOR_BG = 0x000000;      // AMOLED: true black saves power
    const COLOR_PRIMARY = 0xBFE3C8; // muted mint
    const COLOR_SAGE = 0x7FA88A;
    const COLOR_FOREST = 0x1F3D30;
    const COLOR_TEXT = 0xF2EFE6;    // warm ivory
    const COLOR_DIM = 0x8A9A90;

    function centerX(dc as Graphics.Dc) as Number {
        return dc.getWidth() / 2;
    }

    function centerY(dc as Graphics.Dc) as Number {
        return dc.getHeight() / 2;
    }
}
