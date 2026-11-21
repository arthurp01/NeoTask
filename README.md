# NeoTask — Plasma 6 widget

A simple, modern task list for KDE Plasma 6.
English interface, Plasma theme-aware colors (light/dark), no external
dependencies and no network access.

## Features

- Add tasks from the bottom field (Enter or the `+` button)
- Animated check/uncheck, completed tasks are struck through
- Rename a task with the pencil button (Enter saves, Esc cancels)
- Delete a task with the trash button
- Filters **All / To do / Done**
- Remaining task counter and **Clear completed** button
- Automatic saving: each widget keeps its own list
- Compact panel view (icon + active task counter) with a popup on click
- Translucent background card on the desktop, native background in the panel
- Context-menu action **Clear completed tasks**
- Standard text-field shortcuts (Enter validates)

## Installation

### From source

Clone this repository, then from its directory:

```bash
./install.sh
```

Or install it directly with KPackage:

```bash
kpackagetool6 --type Plasma/Applet --install .
```

### Prebuilt package

Download `neotask.plasmoid` from the Releases page, then:

```bash
# First install
kpackagetool6 --type Plasma/Applet --install neotask.plasmoid

# Or update an existing installation
kpackagetool6 --type Plasma/Applet --upgrade neotask.plasmoid
```

### Build the package

```bash
./package.sh
```

This creates `neotask.plasmoid` (ignored by Git), ready to attach to a GitHub
release.

## Add the widget

1. Right-click the desktop → **Enter Edit Mode**
2. **Add Widgets** (or “Add Components”)
3. Search for **NeoTask**
4. Drag it onto the desktop or into a panel

On the desktop the widget can be resized freely. In a panel, only the compact
view is shown; click it to open the task list.

## Usage

- Type a task and press **Enter** (or click `+`).
- Click the circle on the left (or the task text) to complete a task.
- Click the **pencil** on the right to rename a task.
  **Enter** saves, **Esc** cancels.
- Click the **trash** to delete a task.
- Use the filters to show all, active, or completed tasks.
- **Clear completed** removes every checked task.

New tasks are added at the top of the list.

## Data

Tasks are stored by Plasma in the widget configuration
(`~/.config/plasma-org.kde.plasma.desktop-appletsrc`), in each widget
instance’s configuration group. Everything stays local to the machine and
each widget has its own list. Removing the widget does not necessarily remove
its configuration; to start from scratch, remove the widget and its
configuration group, or recreate it.

## Uninstall

```bash
kpackagetool6 --type Plasma/Applet --remove io.github.arthurp01.neotask
```

## Compatibility

- KDE Plasma **6.0+** (developed and tested on Fedora 44 / Plasma 6.8.2)
- Qt 6 / Kirigami 6
- No extra packages required

## Structure

```
neotask/
├── metadata.json                 # plasmoid metadata
├── contents/
│   ├── config/main.xml           # configuration key (tasks as JSON)
│   └── ui/main.qml               # interface and logic
├── install.sh                    # install/update from source
├── package.sh                    # build neotask.plasmoid
├── .gitignore
├── LICENSE
└── README.md
```

## Development

- QML entry point: `contents/ui/main.qml`
- Package ID: `io.github.arthurp01.neotask`
- After editing, run `./install.sh`, then remove/re-add the widget (or restart
  `plasmashell`) to reload the QML.
- Build a distributable archive with `./package.sh`.

## Author

arthurp01

## License

MIT — see [LICENSE](LICENSE).
