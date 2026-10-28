---@meta

---@class hs
---@field logger hs.logger
---@field inspect fun(value: any): string
---@field fs hs.fs
---@field timer hs.timer
---@field mouse hs.mouse
---@field geometry hs.geometry
---@field drawing hs.drawing
---@field fnutils hs.fnutils
---@field application hs.application
---@field axuielement hs.axuielement
---@field screen hs.screen
---@field urlevent hs.urlevent
---@field hotkey hs.hotkey
---@field pathwatcher hs.pathwatcher
---@field task hs.task
---@field alert hs.alert
---@field eventtap hs.eventtap
---@field json hs.json
---@field osascript hs.osascript
---@field usb hs.usb
---@field itunes hs.itunes
---@field caffeinate hs.caffeinate
---@field reload fun()
---@field execute fun(command: string, withUserEnv: boolean|nil): string, boolean

---@class hs.logger
---@field i fun(...: any)
---@field w fun(...: any)
---@field wf fun(format: string, ...: any)
---@field df fun(format: string, ...: any)
---@field ef fun(format: string, ...: any)
---@field f fun(format: string, ...: any)
---@field e fun(...: any)

---@class hs.fs
---@field attributes fun(path: string): table|boolean|nil
---@field mkdir fun(path: string): boolean
---@field displayName fun(path: string): string

---@class hs.timer
---@field usleep fun(microseconds: number): nil
---@field doAfter fun(delay: number, callback: fun()): hs.timer
---@field doEvery fun(interval: number, callback: fun()): hs.timer

---@class hs.mouse
---@field getAbsolutePosition fun(): table
---@field absolutePosition fun(point: table): nil

---@class hs.geometry
---@field point fun(x: number, y: number): table
---@field rect fun(x: number, y: number, w: number, h: number): table

---@class hs.drawing
---@field circle fun(rect: table): hs.drawing.circle

---@class hs.drawing.circle
---@field setFillColor fun(self, color: table): nil
---@field show fun(self): nil
---@field delete fun(self): nil

---@class hs.fnutils
---@field map fun(list: table, fn: fun(item: any, key: any): any): table
---@field filter fun(list: table, fn: fun(item: any): boolean): table
---@field imap fun(list: table, fn: fun(item: any, index: number): any): table
---@field indexOf fun(list: table, value: any): number
---@field each fun(list: table, fn: fun(item: any, key: any): nil): nil

---@class hs.application
---@field get fun(name: string): hs.application|nil
---@field watcher hs.application.watcher
---@field enableSpotlightForNameSearches fun(enabled: boolean): nil
---@field launchOrFocus fun(appName: string): boolean
---@field launchOrFocusByBundleID fun(bundleId: string): boolean
---@field frontmostApplication fun(): hs.application|nil
---@field focusedWindow fun(self): hs.window|nil
---@field allWindows fun(self): hs.window[]
---@field name fun(self): string
---@field path fun(self): string|nil
---@field pid fun(self): number
---@field bundleID fun(self): string
---@field kill fun(self): nil

---@class hs.application.watcher
---@field activated number
---@field launched number
---@field launching number
---@field unhidden number
---@field new fun(fn: fun(appName: string, event: number, app: hs.application): nil): hs.application.watcher
---@field start fun(self): hs.application.watcher
---@field stop fun(self): nil

---@class hs.window
---@field find fun(name: string): hs.window|nil
---@field frontmostWindow fun(): hs.window|nil
---@field focusedWindow fun(): hs.window|nil
---@field application fun(self): hs.application
---@field title fun(self): string
---@field frame fun(self): table
---@field screen fun(self): hs.screen
---@field id fun(self): number
---@field isStandard fun(self): boolean
---@field focus fun(self): nil
---@field becomeMain fun(self): nil
---@field path fun(self): string|nil
---@field titleBarHeight fun(self): number
---@field moveToScreen fun(self, screen: hs.screen): nil
---@field move fun(self, rect: table, screen: hs.screen|nil): nil

---@class hs.screen
---@field mainScreen fun(): hs.screen
---@field frame fun(self): table
---@field fullFrame fun(self): table
---@field toUnitRect fun(self, rect: table): table
---@field next fun(self): hs.screen|nil
---@field previous fun(self): hs.screen|nil

---@class hs.axuielement
---@field windowElement fun(window: hs.window): hs.axuielement
---@field systemElementAtPosition fun(point: table): hs.axuielement|nil
---@field applicationElement fun(app: hs.application): hs.axuielement
---@field pid fun(self): number
---@field attributeValue fun(self, name: string): any
---@field setAttributeValue fun(self, name: string, value: any): nil
---@field title fun(self): string
---@field application fun(self): hs.application
---@field elementSearch fun(self, fn: fun(message: string, results: table): nil, predicate: fun(element: hs.axuielement): boolean, options: table): nil
---@field performAction fun(self, action: string): nil

---@class hs.urlevent
---@field openURL fun(url: string): nil
---@field openURLWithBundle fun(url: string, bundleId: string): nil

---@class hs.hotkey
---@field new fun(modifiers: string[], key: string, fn: function|nil): hs.hotkey
---@field enable fun(self): nil
---@field disable fun(self): nil
---@field alertDuration number

---@class hs.pathwatcher
---@field new fun(fn: fun(files: table): nil): hs.pathwatcher
---@field start fun(self): hs.pathwatcher
---@field stop fun(self): nil

---@class hs.task
---@field new fun(launchPath: string, callback: fun(exitCode: number, stdOut: string, stdErr: string)|nil, streamCallbackOrArgs: function|string[]|nil, args: string[]|nil): hs.task
---@field start fun(self): hs.task|false
---@field isRunning fun(self): boolean
---@field terminate fun(self): hs.task
---@field pid fun(self): number
---@field setEnvironment fun(self, env: table<string, string>): boolean
---@field setWorkingDirectory fun(self, path: string): boolean

---@class hs.alert
---@field show fun(message: string): nil

---@class hs.eventtap
---@field keyStroke fun(modifiers: string[], key: string): nil
---@field keyStrokes fun(chars: string): nil

---@class hs.json
---@field read fun(path: string): table|nil
---@field write fun(value: table, path: string, pretty: boolean, newline: boolean): boolean

---@class hs.osascript
---@field javascript fun(source: string): any, string

---@class hs.usb
---@field watcher hs.usb.watcher
---@class hs.usb.watcher
---@field new fun(fn: fun(event: table): nil): hs.usb.watcher
---@field start fun(self): hs.usb.watcher

---@class hs.itunes
---@field pause fun(): nil

---@class hs.caffeinate
---@field systemSleep fun(): nil
