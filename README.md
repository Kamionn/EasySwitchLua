# EasySwitchLua

Un système de switch avancé et performant pour Lua avec gestion d'événements, middleware et cache optimisé.

## ⚡ Installation

```lua
-- Copier les fichiers dans votre projet
local Switch = require("easyswitch")
```

## 🚀 Utilisation Simple

```lua
local Switch = require("easyswitch")

-- Création d'un switch basique
local menuSwitch = Switch("menu")
    :when("start", function()
        return "Game started"
    end)
    :when("quit", function()
        return "Game ended"
    end)
    :default(function(action)
        return "Unknown action: " .. action
    end)

-- Utilisation
print(menuSwitch:execute("start"))  -- "Game started"
print(menuSwitch:execute("quit"))   -- "Game ended"
print(menuSwitch:execute("other"))  -- "Unknown action: other"

-- Cas multiples
local commandSwitch = Switch("commands")
    :when({"save", "backup"}, function(action)
        return "Saving game..."
    end)

print(commandSwitch:execute("save"))    -- "Saving game..."
print(commandSwitch:execute("backup"))  -- "Saving game..."
```

## 🔥 Fonctionnalités Avancées

### Middleware
```lua
local authSwitch = Switch("auth")
    -- Transformation des entrées
    :use(function(action)
        return string.upper(action)
    end)
    :when("LOGIN", function()
        return "Logging in..."
    end)

print(authSwitch:execute("login"))  -- "Logging in..."
```

### Events (Debug/Logging)
```lua
local debugSwitch = Switch("debug")
    -- Avant exécution
    :on("beforeExecute", function(value)
        print("Executing:", value)
    end)
    -- Après exécution
    :on("afterExecute", function(value, result)
        print("Result:", result)
    end)
    -- En cas d'erreur
    :on("error", function(type, err)
        print("Error in", type .. ":", err)
    end)
    :when("test", function()
        return "test ok"
    end)

debugSwitch:execute("test")
```

### Cache Automatique
Le système met automatiquement en cache les résultats avec une gestion intelligente de la mémoire via les pairs.

```lua
local expensiveSwitch = Switch("expensive")
    :when("calc", function()
        -- Opération coûteuse
        local result = 0
        for i = 1, 1000000 do
            result = result + i
        end
        return result
    end)

-- Premier appel : calcule
print(expensiveSwitch:execute("calc"))
-- Deuxième appel : utilise le cache
print(expensiveSwitch:execute("calc"))
```

## ⚙️ Configuration

```lua
local switch = Switch("config", {
    maxCases = 1000  -- Limite de cas (défaut: 100)
})
```

## 📋 Events Disponibles

- `beforeExecute` : Avant l'exécution
- `afterExecute` : Après l'exécution
- `error` : En cas d'erreur
- `cacheHit` : Cache trouvé
- `cacheMiss` : Cache manqué
- `middlewareStart` : Début du middleware
- `middlewareEnd` : Fin du middleware
- `noMatch` : Pas de correspondance

## 🎮 Exemple Complet (State Machine)

```lua
local gameState = {
    score = 0,
    lives = 3
}

local gameSwitch = Switch("game")
    -- Middleware pour logging
    :use(function(action)
        print("Game action:", action)
        return action
    end)
    -- Events pour debug
    :on("beforeExecute", function(action)
        print("Current state - Score:", gameState.score, "Lives:", gameState.lives)
    end)
    -- Actions du jeu
    :when("start", function()
        gameState.score = 0
        gameState.lives = 3
        return "PLAYING"
    end)
    :when("hit", function()
        gameState.lives = gameState.lives - 1
        return gameState.lives > 0 and "PLAYING" or "GAME_OVER"
    end)
    :when("score", function()
        gameState.score = gameState.score + 100
        return "PLAYING"
    end)
    :default(function(action)
        return "UNKNOWN_ACTION"
    end)

-- Simulation de jeu
print(gameSwitch:execute("start"))    -- Reset et commence
print(gameSwitch:execute("score"))    -- Score +100
print(gameSwitch:execute("hit"))      -- Perd une vie
```

## 🔧 Performance

Le système utilise plusieurs optimisations :
- Cache avec pairs pour gestion automatique de la mémoire
- Compilation des middlewares
- Minimisation des lookups
- Chaînage des méthodes fluide

## 🤝 Contribution

Les contributions sont bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## 📄 License

[MIT License](LICENSE.md)
