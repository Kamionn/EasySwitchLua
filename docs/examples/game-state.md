# Example — Game state machine

[← Docs index](../README.md)

A LÖVE2D-style state machine. Each state has a `draw` action ; transitions are triggered by key presses, dispatched through a second switch.

---

## Goal

```
States   :  menu    →  game    →  pause  →  game-over
Inputs   :  Enter / Esc / R / Space
```

---

## State render dispatcher

```lua
local EasySwitch = require("easyswitch")
local P = EasySwitch.P

local renderState = EasySwitch.new()
    :when("menu", function()
        love.graphics.print("MAIN MENU\n[Enter] Start", 10, 10)
    end)
    :when("game", function()
        love.graphics.print("GAME RUNNING\n[Esc] Pause", 10, 10)
    end)
    :when("pause", function()
        love.graphics.print("PAUSED\n[Esc] Resume    [R] Reset", 10, 10)
    end)
    :when("game-over", function()
        love.graphics.print("GAME OVER\n[Space] Back to menu", 10, 10)
    end)
    :default(function(state)
        love.graphics.print("Unknown state: " .. tostring(state), 10, 10)
    end)
    :on("noMatch", function(state) print("[warn] unhandled state:", state) end)
```

---

## Transition dispatcher

A second switch maps `(currentState, key)` to the next state. The input is a partial shape ; extra fields on the input table are ignored.

```lua
local nextState = EasySwitch.new()
    -- From the menu, only Enter advances.
    :when({ from = "menu",      key = "return"   }, function() return "game"     end)

    -- In game, Esc pauses.
    :when({ from = "game",      key = "escape"   }, function() return "pause"    end)

    -- While paused, Esc resumes ; R resets to menu.
    :when({ from = "pause",     key = "escape"   }, function() return "game"     end)
    :when({ from = "pause",     key = "r"        }, function() return "menu"     end)

    -- On game-over, Space goes back to menu.
    :when({ from = "game-over", key = "space"    }, function() return "menu"     end)

    -- Any P-key in any state forces game-over (cheat code, why not).
    :when({ key = "p" }, function() return "game-over" end)

    -- Unhandled inputs : stay where we are.
    :default(function(input) return input.from end)
```

---

## LÖVE2D wiring

```lua
local current = "menu"

function love.draw()
    renderState:execute(current)
end

function love.keypressed(key)
    current = nextState:execute({ from = current, key = key })
end
```

That's the entire state machine. Six rules for transitions, four for rendering, three lines of love.* glue.

---

## What this example demonstrates

| Technique | Where | Why |
|---|---|---|
| Two cooperating switches | render + transitions | Single-responsibility — one for "what to draw", one for "how to move" |
| Partial shape pattern | `{ from = "...", key = "..." }` | Easy multi-field matching, ignores extras |
| Wildcard partial | `{ key = "p" }` | Matches any state, only constrains the key |
| `:default` returns input | `function(input) return input.from end` | "Stay in current state" is just `from` |
| `:on("noMatch")` | render switch | Catches typos in state names early |

---

## Adding events / scoring

The transition switch is a great place to fire events without polluting the rendering logic :

```lua
nextState:on("afterExecute", function(input, newState)
    if newState ~= input.from then
        print("transition:", input.from, "→", newState)
        on_state_change(input.from, newState)
    end
end)
```

`afterExecute` always fires (with the dispatch result), so you can route it to your scoring / audio / save-game code without touching the dispatch rules.

---

## Memoize is NOT appropriate here

The state machine is a great example of **when not to memoize**. Each `nextState:execute(input)` is called with a fresh table (different identity each frame), so the cache would never hit anyway. Worse : if it could hit, side effects in `afterExecute` would be skipped on subsequent calls.

The render switch could theoretically memoize (`renderState:memoize()`), but `love.graphics.print` writes to the screen — it's a pure side-effect action with no useful return value. Memoize would prevent it from ever drawing the same state twice. Don't.

> [!TIP]
> Memoize is for **pure dispatchers that return derived data**. State machines, renderers, event handlers — leave memoize off.

---

## Variations

### Discriminated union via DSL strict shape

If you want to enforce exactly the input shape `{ from, key }` and reject typos like `{ form, key }`, use `P.shape` or DSL `{| ... |}` :

```lua
nextState:when("{| from: 'menu', key: 'return' |}", function() return "game" end)
nextState:when("{| from: 'game', key: 'escape' |}", function() return "pause" end)
```

Strict shape catches `from = "main_menu"` (typo'd state name) at runtime — no rule matches, default fires, you see the bug immediately.

### Wider state model

For real games, the state is more than a string. Make it a table and pattern-match deeper :

```lua
local current = { name = "menu", lives = 3, score = 0 }

renderState:when({ name = "game" }, function(s)
    love.graphics.print(("Score: %d  Lives: %d"):format(s.score, s.lives), 10, 10)
end)
```

The partial shape `{ name = "game" }` matches any state with `name = "game"`, regardless of `lives` / `score` content.

---

## See also

- **[Pattern matching guide](../guides/pattern-matching.md)** — bare table partial vs strict shape
- **[FALLTHROUGH guide](../guides/fallthrough.md)** — when one rule fires effects and another produces the result
- **[Events API](../api/events.md)** — listening to transitions
