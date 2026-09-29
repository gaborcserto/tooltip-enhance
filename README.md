# TooltipEnhance

TooltipEnhance is a World of Warcraft addon for adding configurable information and visual adjustments to tooltips.

## Features

- Optional unit, spell, mount, item, toy, currency, quest, and macro IDs.
- Optional player details including mount, target, Mythic+ score, best Mythic+ run, guild rank, honor level, PvP status, and inspected average/max item level.
- Tooltip background opacity and border color modes (black, class color, or unit reaction).
- Optional tooltip scaling, cursor anchoring, combat hiding, and LibSharedMedia-3.0 font support.
- Instance and combat safety checks for player-related data.

## Installation

Copy the `TooltipEnhance` folder into your World of Warcraft `Interface/AddOns` directory. Make sure the folder contains `TooltipEnhance.toc` directly.

## Configuration

Open the World of Warcraft Settings panel and select TooltipEnhance. Enable the options you want; changes are stored in the `TESettings` saved variable.

## Development

The addon is written in Lua and uses the Blizzard Settings API. LibSharedMedia-3.0 is optional and is only used for custom tooltip fonts. The `.toc` file is the authoritative load order and addon metadata source.

## License

TooltipEnhance is released under the [MIT License](LICENSE).
