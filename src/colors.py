def esc(code):
    return f'\033[{code}m'

RESET           = esc(0)
BLACK           = esc(30)
RED             = esc(31)
GREEN           = esc(32)
YELLOW          = esc(33)
BLUE            = esc(34)
MAGENTA         = esc(35)
CYAN            = esc(36)
WHITE           = esc(37)
DEFAULT         = esc(39)
LIGHT_BLACK     = esc(90)
LIGHT_RED       = esc(91)
LIGHT_GREEN     = esc(92)
LIGHT_YELLOW    = esc(93)
LIGHT_BLUE      = esc(94)
LIGHT_MAGENTA   = esc(95)
LIGHT_CYAN      = esc(96)
LIGHT_WHITE     = esc(97)

BG_BLACK           = esc(40)
BG_RED             = esc(41)
BG_GREEN           = esc(42)
BG_YELLOW          = esc(43)
BG_BLUE            = esc(44)
BG_MAGENTA         = esc(45)
BG_CYAN            = esc(46)
BG_WHITE           = esc(47)
BG_DEFAULT         = esc(49)

CLEAR_LINE         = "\033[K"
