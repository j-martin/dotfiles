#!/usr/bin/env python3.7

import iterm2


async def main(connection):
    app = await iterm2.async_get_app(connection)

    all_windows = app.terminal_windows
    all_tabs = [tab for window in all_windows for tab in window.tabs]

    await all_windows[0].async_set_tabs(all_tabs)


iterm2.run_until_complete(main)
