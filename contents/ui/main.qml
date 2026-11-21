/*
    SPDX-FileCopyrightText: 2026 arthurp01

    SPDX-License-Identifier: MIT
*/

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ---------------------------------------------------------------------
    // Data
    // ---------------------------------------------------------------------

    // Source of truth: array of { id, text, done }
    property var todos: []

    // 0 = all, 1 = to do, 2 = done
    property int filterMode: 0

    // Task being renamed (id) and current edit draft
    property string editingId: ""
    property string editDraft: ""

    readonly property int activeCount: {
        let count = 0;
        for (let i = 0; i < todos.length; ++i) {
            if (!todos[i].done) {
                count++;
            }
        }
        return count;
    }
    readonly property int doneCount: todos.length - activeCount
    readonly property bool allDone: todos.length > 0 && activeCount === 0

    readonly property bool isDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property int contentMargin: isDesktop
        ? Math.round(Kirigami.Units.gridUnit * 0.9)
        : Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing

    // Filtered model displayed by the ListView
    ListModel {
        id: displayModel
    }

    Plasmoid.title: "NeoTask"
    Plasmoid.backgroundHints: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? PlasmaCore.Types.NoBackground
        : PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    // Desktop: full view. Panel: compact view + popup.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null

    toolTipMainText: "NeoTask"
    toolTipSubText: root.summaryText()

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Clear completed tasks"
            icon.name: "edit-clear-all"
            enabled: root.doneCount > 0
            onTriggered: root.clearCompleted()
        }
    ]

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function makeId() {
        return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8);
    }

    function summaryText() {
        if (todos.length === 0) {
            return "No tasks";
        }
        if (activeCount === 0) {
            return "All done";
        }
        return activeCount + (activeCount === 1 ? " task left" : " tasks left");
    }

    function statusText() {
        if (todos.length === 0) {
            return "No tasks";
        }
        if (filterMode === 1) {
            return activeCount === 0
                ? "No tasks to do"
                : activeCount + (activeCount === 1 ? " task to do" : " tasks to do");
        }
        if (filterMode === 2) {
            return doneCount === 0
                ? "No tasks done"
                : doneCount + (doneCount === 1 ? " task done" : " tasks done");
        }
        return summaryText();
    }

    function emptyTitle() {
        if (todos.length === 0) {
            return "No tasks";
        }
        if (filterMode === 1) {
            return "All done";
        }
        if (filterMode === 2) {
            return "Nothing done yet";
        }
        return "No tasks";
    }

    function emptyHint() {
        if (todos.length === 0) {
            return "Add one below.";
        }
        if (filterMode === 1) {
            return "Enjoy your day!";
        }
        return "Completed tasks will appear here.";
    }

    // ---------------------------------------------------------------------
    // Persistence (in the plasmoid configuration)
    // ---------------------------------------------------------------------

    function persist() {
        Plasmoid.configuration.todos = JSON.stringify(root.todos);
        Plasmoid.configuration.writeConfig();
    }

    function loadTodos() {
        let parsed = [];
        const raw = Plasmoid.configuration.todos;

        if (raw && raw.length > 0) {
            try {
                parsed = JSON.parse(raw);
            } catch (error) {
                parsed = [];
            }
        }

        const cleaned = [];
        if (Array.isArray(parsed)) {
            for (let i = 0; i < parsed.length; ++i) {
                const item = parsed[i];
                if (!item || typeof item.text !== "string") {
                    continue;
                }
                const text = item.text.trim();
                if (text.length === 0) {
                    continue;
                }
                cleaned.push({
                    id: typeof item.id === "string" && item.id.length > 0 ? item.id : makeId(),
                    text: text.substring(0, 500),
                    done: item.done === true
                });
            }
        }

        editingId = "";
        editDraft = "";
        todos = cleaned;
        filterMode = 0;
        refreshDisplay();
    }

    // ---------------------------------------------------------------------
    // Mutations
    // ---------------------------------------------------------------------

    function matchesFilter(todo) {
        if (filterMode === 1) {
            return !todo.done;
        }
        if (filterMode === 2) {
            return todo.done;
        }
        return true;
    }

    function refreshDisplay() {
        displayModel.clear();
        for (let i = 0; i < todos.length; ++i) {
            const todo = todos[i];
            if (matchesFilter(todo)) {
                displayModel.append({
                    todoId: todo.id,
                    todoText: todo.text,
                    todoDone: todo.done
                });
            }
        }
    }

    function displayIndexFor(id) {
        for (let i = 0; i < displayModel.count; ++i) {
            if (displayModel.get(i).todoId === id) {
                return i;
            }
        }
        return -1;
    }

    function addTodo(rawText) {
        const text = String(rawText || "").trim().substring(0, 500);
        if (text.length === 0) {
            return false;
        }
        if (editingId.length > 0) {
            commitRename(editingId, editDraft);
        }

        const todo = { id: makeId(), text: text, done: false };
        todos = [todo].concat(todos);

        if (filterMode !== 0) {
            filterMode = 0;
            refreshDisplay();
        } else {
            displayModel.insert(0, {
                todoId: todo.id,
                todoText: todo.text,
                todoDone: false
            });
        }

        persist();
        return true;
    }

    function startRename(id) {
        if (editingId === id) {
            return;
        }

        // Save the current edit before opening another one.
        if (editingId.length > 0) {
            commitRename(editingId, editDraft);
        }

        for (let i = 0; i < todos.length; ++i) {
            if (todos[i].id === id) {
                editDraft = todos[i].text;
                editingId = id;
                return;
            }
        }
    }

    function commitRename(id, value) {
        if (editingId !== id) {
            return;
        }

        const text = String(value || "").trim().substring(0, 500);
        editingId = "";
        editDraft = "";

        // An empty name cancels the rename and keeps the previous name.
        if (text.length === 0) {
            return;
        }

        let changed = false;
        const next = [];
        for (let i = 0; i < todos.length; ++i) {
            const todo = todos[i];
            if (todo.id === id) {
                if (todo.text === text) {
                    next.push(todo);
                } else {
                    next.push({ id: todo.id, text: text, done: todo.done });
                    changed = true;
                }
            } else {
                next.push(todo);
            }
        }

        if (!changed) {
            return;
        }

        todos = next;
        const displayIndex = displayIndexFor(id);
        if (displayIndex >= 0) {
            displayModel.setProperty(displayIndex, "todoText", text);
        }
        persist();
    }

    function cancelRename(id) {
        if (editingId !== id) {
            return;
        }
        editingId = "";
        editDraft = "";
    }

    function toggleTodo(id) {
        if (editingId.length > 0) {
            commitRename(editingId, editDraft);
        }

        let index = -1;
        for (let i = 0; i < todos.length; ++i) {
            if (todos[i].id === id) {
                index = i;
                break;
            }
        }
        if (index < 0) {
            return;
        }

        const current = todos[index];
        const updated = {
            id: current.id,
            text: current.text,
            done: !current.done
        };

        const next = todos.slice();
        next[index] = updated;
        todos = next;

        if (filterMode === 0) {
            const displayIndex = displayIndexFor(id);
            if (displayIndex >= 0) {
                displayModel.setProperty(displayIndex, "todoDone", updated.done);
            }
        } else {
            refreshDisplay();
        }

        persist();
    }

    function removeTodo(id) {
        if (editingId.length > 0) {
            commitRename(editingId, editDraft);
        }

        const next = [];
        let found = false;

        for (let i = 0; i < todos.length; ++i) {
            if (todos[i].id === id) {
                found = true;
            } else {
                next.push(todos[i]);
            }
        }
        if (!found) {
            return;
        }

        todos = next;

        const displayIndex = displayIndexFor(id);
        if (displayIndex >= 0) {
            displayModel.remove(displayIndex);
        }

        persist();
    }

    function clearCompleted() {
        if (editingId.length > 0) {
            commitRename(editingId, editDraft);
        }
        if (doneCount === 0) {
            return;
        }

        const next = [];
        for (let i = 0; i < todos.length; ++i) {
            if (!todos[i].done) {
                next.push(todos[i]);
            }
        }
        todos = next;

        for (let i = displayModel.count - 1; i >= 0; --i) {
            if (displayModel.get(i).todoDone) {
                displayModel.remove(i);
            }
        }

        persist();
    }

    function setFilter(mode) {
        if (filterMode === mode) {
            return;
        }
        if (editingId.length > 0) {
            commitRename(editingId, editDraft);
        }
        filterMode = mode;
        refreshDisplay();
    }

    Component.onCompleted: loadTodos()

    onExpandedChanged: function(isExpanded) {
        if (!isExpanded && editingId.length > 0) {
            commitRename(editingId, editDraft);
        }
    }

    // ---------------------------------------------------------------------
    // Compact view (panel)
    // ---------------------------------------------------------------------

    compactRepresentation: Item {
        id: compactRoot

        implicitWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: compactRow.implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                source: "checkmark"
                color: root.allDone ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                opacity: 0.9
            }

            Rectangle {
                readonly property real badgeHeight: Math.round(Kirigami.Units.gridUnit * 0.9)

                visible: root.activeCount > 0
                Layout.preferredHeight: badgeHeight
                Layout.preferredWidth: Math.max(badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 1.5, badgeHeight)
                radius: badgeHeight / 2
                color: Kirigami.Theme.highlightColor

                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.activeCount > 99 ? "99+" : root.activeCount
                    color: Kirigami.Theme.highlightedTextColor
                    font.pointSize: Math.max(Kirigami.Theme.defaultFont.pointSize * 0.78, 7)
                    font.bold: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // ---------------------------------------------------------------------
    // Full view (desktop / panel popup)
    // ---------------------------------------------------------------------

    fullRepresentation: Item {
        id: fullRoot

        implicitWidth: Kirigami.Units.gridUnit * 18
        implicitHeight: Kirigami.Units.gridUnit * 22
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 15
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22

        function submit() {
            if (root.addTodo(composer.text)) {
                composer.text = "";
                taskList.positionViewAtBeginning();
            }
            composer.forceActiveFocus();
        }

        // Desktop background card (the panel popup keeps its native background)
        Rectangle {
            anchors.fill: parent
            visible: root.isDesktop
            radius: Kirigami.Units.gridUnit
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                           Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b,
                           0.94)
            border.width: 1
            border.color: root.withAlpha(Kirigami.Theme.textColor, 0.10)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.contentMargin
            spacing: Kirigami.Units.largeSpacing

            // Header ------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Text {
                    Layout.fillWidth: true
                    text: "NeoTask"
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    readonly property real pillHeight: Math.round(Kirigami.Units.gridUnit * 1.35)

                    visible: root.activeCount > 0
                    Layout.preferredHeight: pillHeight
                    Layout.preferredWidth: Math.max(pendingLabel.implicitWidth + Kirigami.Units.smallSpacing * 2, pillHeight)
                    radius: pillHeight / 2
                    color: root.withAlpha(Kirigami.Theme.highlightColor, 0.18)

                    Text {
                        id: pendingLabel
                        anchors.centerIn: parent
                        text: root.activeCount
                        color: Kirigami.Theme.highlightColor
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                        font.bold: true
                    }
                }
            }

            // Filters ------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 1.8)
                radius: height / 2
                color: root.withAlpha(Kirigami.Theme.textColor, 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: [
                            { label: "All", mode: 0 },
                            { label: "To do", mode: 1 },
                            { label: "Done", mode: 2 }
                        ]

                        delegate: Item {
                            id: filterTab

                            readonly property var tabData: modelData
                            readonly property bool selected: root.filterMode === tabData.mode

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: filterTab.selected ? Kirigami.Theme.highlightColor : "transparent"
                                Behavior on color {
                                    ColorAnimation { duration: 140 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: filterTab.tabData.label
                                color: filterTab.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                opacity: filterTab.selected ? 1 : 0.8
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.88
                                font.weight: filterTab.selected ? Font.DemiBold : Font.Normal
                                Behavior on color {
                                    ColorAnimation { duration: 140 }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.setFilter(filterTab.tabData.mode);
                                    taskList.positionViewAtBeginning();
                                }
                            }
                        }
                    }
                }
            }

            // List --------------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 5

                ListView {
                    id: taskList

                    anchors.fill: parent
                    visible: count > 0
                    clip: true
                    spacing: 1
                    model: displayModel
                    boundsBehavior: Flickable.StopAtBounds

                    PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                        id: scrollBar
                    }

                    add: Transition {
                        NumberAnimation {
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: 140
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 120
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }

                    delegate: Item {
                        id: todoRow

                        readonly property string todoId: model.todoId
                        readonly property string todoText: model.todoText
                        readonly property bool todoDone: model.todoDone
                        readonly property bool editing: root.editingId === todoId

                        width: taskList.width
                        height: Math.max(rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2,
                                         Kirigami.Units.gridUnit * 2.1)

                        HoverHandler {
                            id: rowHover
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: rowHover.hovered
                                ? root.withAlpha(Kirigami.Theme.textColor, 0.05)
                                : "transparent"
                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                        }

                        RowLayout {
                            id: rowLayout

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing * 1.5

                            // Checkbox
                            Item {
                                Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 1.15)
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: todoRow.todoDone ? Kirigami.Theme.highlightColor : "transparent"
                                    border.width: todoRow.todoDone ? 0 : 1.5
                                    border.color: root.withAlpha(Kirigami.Theme.textColor, 0.35)
                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }
                                }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Math.round(parent.width * 0.62)
                                    height: width
                                    source: "checkmark"
                                    color: Kirigami.Theme.highlightedTextColor
                                    opacity: todoRow.todoDone ? 1 : 0
                                    scale: todoRow.todoDone ? 1 : 0.5
                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleTodo(todoRow.todoId)
                                }
                            }

                            // Text
                            Text {
                                visible: !todoRow.editing
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: todoRow.todoText
                                color: todoRow.todoDone
                                    ? Kirigami.Theme.disabledTextColor
                                    : Kirigami.Theme.textColor
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                font.strikeout: todoRow.todoDone
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleTodo(todoRow.todoId)
                                }
                            }

                            // Rename
                            PlasmaComponents3.TextField {
                                id: renameField

                                visible: todoRow.editing
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 1.8)
                                maximumLength: 500
                                selectByMouse: true
                                color: Kirigami.Theme.textColor
                                leftPadding: Kirigami.Units.smallSpacing * 2
                                rightPadding: Kirigami.Units.smallSpacing * 2

                                function startEditing() {
                                    // Start from the saved name (discard any previous draft).
                                    text = todoRow.todoText;
                                    Qt.callLater(function() {
                                        if (renameField.visible) {
                                            renameField.forceActiveFocus();
                                            renameField.selectAll();
                                        }
                                    });
                                }

                                onVisibleChanged: {
                                    if (visible) {
                                        startEditing();
                                    }
                                }
                                Component.onCompleted: {
                                    if (visible) {
                                        startEditing();
                                    }
                                }

                                onTextEdited: {
                                    if (root.editingId === todoRow.todoId) {
                                        root.editDraft = text;
                                    }
                                }
                                onAccepted: root.commitRename(todoRow.todoId, text)
                                onEditingFinished: root.commitRename(todoRow.todoId, text)
                                Keys.onEscapePressed: {
                                    root.cancelRename(todoRow.todoId);
                                    event.accepted = true;
                                }

                                background: Rectangle {
                                    radius: Kirigami.Units.cornerRadius
                                    color: root.withAlpha(Kirigami.Theme.textColor, 0.08)
                                    border.width: 1
                                    border.color: root.withAlpha(Kirigami.Theme.highlightColor, 0.7)
                                }
                            }

                            // Rename
                            Item {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                                visible: !todoRow.editing

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: "edit-rename"
                                    color: editMouse.containsMouse
                                        ? Kirigami.Theme.highlightColor
                                        : Kirigami.Theme.disabledTextColor
                                    opacity: editMouse.containsMouse ? 1 : (rowHover.hovered ? 0.85 : 0.3)
                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                MouseArea {
                                    id: editMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.startRename(todoRow.todoId)
                                }
                            }

                            // Delete
                            Item {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                                visible: !todoRow.editing

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: "edit-delete"
                                    color: deleteMouse.containsMouse
                                        ? Kirigami.Theme.negativeTextColor
                                        : Kirigami.Theme.disabledTextColor
                                    opacity: deleteMouse.containsMouse ? 1 : (rowHover.hovered ? 0.85 : 0.3)
                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeTodo(todoRow.todoId)
                                }
                            }
                        }
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, Kirigami.Units.gridUnit * 12)
                    spacing: Kirigami.Units.smallSpacing
                    visible: taskList.count === 0

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Kirigami.Units.gridUnit * 4.5
                        height: width
                        radius: width / 2
                        color: root.withAlpha(Kirigami.Theme.highlightColor, 0.12)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.45)
                            height: width
                            source: root.todos.length === 0 ? "list-add" : "checkmark"
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.9
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.emptyTitle()
                        color: Kirigami.Theme.textColor
                        opacity: 0.85
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.emptyHint()
                        color: Kirigami.Theme.disabledTextColor
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.88
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Footer -------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: root.todos.length > 0

                Text {
                    Layout.fillWidth: true
                    text: root.statusText()
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.82
                }

                Item {
                    Layout.preferredWidth: clearLabel.implicitWidth + Kirigami.Units.smallSpacing
                    Layout.preferredHeight: clearLabel.implicitHeight + 4
                    visible: root.doneCount > 0

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear completed"
                        color: clearMouse.containsMouse
                            ? Kirigami.Theme.negativeTextColor
                            : Kirigami.Theme.disabledTextColor
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.82
                        font.underline: clearMouse.containsMouse
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearCompleted()
                    }
                }
            }

            // Composer -----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.TextField {
                    id: composer

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 2.1)
                    placeholderText: "Add a task…"
                    placeholderTextColor: Kirigami.Theme.disabledTextColor
                    color: Kirigami.Theme.textColor
                    maximumLength: 500
                    leftPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                    rightPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                    onAccepted: fullRoot.submit()

                    background: Rectangle {
                        radius: height / 2
                        color: root.withAlpha(Kirigami.Theme.textColor, 0.06)
                        border.width: 1
                        border.color: composer.activeFocus
                            ? root.withAlpha(Kirigami.Theme.highlightColor, 0.65)
                            : "transparent"
                    }
                }

                Item {
                    id: addButton

                    readonly property bool canAdd: composer.text.trim().length > 0

                    Layout.preferredWidth: composer.height
                    Layout.preferredHeight: composer.height

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: addButton.canAdd
                            ? Kirigami.Theme.highlightColor
                            : root.withAlpha(Kirigami.Theme.textColor, 0.08)
                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.5)
                        height: width
                        source: "list-add"
                        color: addButton.canAdd
                            ? Kirigami.Theme.highlightedTextColor
                            : Kirigami.Theme.disabledTextColor
                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: addButton.canAdd
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: fullRoot.submit()
                    }
                }
            }
        }
    }
}
