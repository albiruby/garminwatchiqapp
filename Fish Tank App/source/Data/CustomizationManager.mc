import Toybox.Lang;

// Art style picks the renderer; theme picks content. Both are plain numbers in the save,
// so switching either never touches fish, coins or level.
module CustomizationManager {
    const STYLE_COUNT = 3;
    const THEME_COUNT = 4;
    const STYLE_NAME = ["Modern Pixel", "Minimalist", "Pseudo-3D"];
    const STYLE_DESC = ["Crisp 16-bit sprites", "Calm, clean, ambient", "Layered depth & parallax"];

    var _renderers = [null, null, null];

    function renderer(style) {
        if (_renderers[style] == null) {
            if (style == 1) {
                _renderers[style] = new MinimalRenderer();
            } else if (style == 2) {
                _renderers[style] = new DepthRenderer();
            } else {
                _renderers[style] = new ModernRenderer();
            }
        }
        return _renderers[style];
    }
}
